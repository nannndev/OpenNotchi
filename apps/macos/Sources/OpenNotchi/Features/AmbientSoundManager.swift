import AVFoundation
import Combine
import Foundation

enum AmbientSound: String, CaseIterable, Identifiable, Codable {
    case rain = "rain"
    case brownNoise = "brownNoise"
    case vinyl = "vinyl"
    case fireplace = "fireplace"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: return "Midnight Rain"
        case .brownNoise: return "Brown Noise"
        case .vinyl: return "Vinyl Crackle"
        case .fireplace: return "Cozy Hearth"
        }
    }

    var shortTitle: String {
        switch self {
        case .rain: return "Rain"
        case .brownNoise: return "Brown"
        case .vinyl: return "Vinyl"
        case .fireplace: return "Hearth"
        }
    }

    var icon: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .brownNoise: return "waveform.path"
        case .vinyl: return "opticaldisc.fill"
        case .fireplace: return "flame.fill"
        }
    }

    var defaultVolume: Float {
        switch self {
        case .rain: return 0.65
        case .brownNoise: return 0.55
        case .vinyl: return 0.45
        case .fireplace: return 0.50
        }
    }
}

/// Real-time procedural ambient soundscape mixer powered by AVAudioEngine.
/// Layers underneath Spotify / Apple Music and optionally auto-plays during Pomodoro Focus sessions.
final class AmbientSoundManager: ObservableObject {
    static let shared = AmbientSoundManager()

    @Published private(set) var activeSounds: Set<AmbientSound> = []
    @Published private(set) var volumes: [AmbientSound: Float] = [:]
    @Published var masterVolume: Float {
        didSet {
            UserDefaults.standard.set(masterVolume, forKey: "ambientMasterVolume")
            syncAtomicState()
        }
    }
    @Published var autoPlayWithFocusTimer: Bool {
        didSet {
            UserDefaults.standard.set(autoPlayWithFocusTimer, forKey: "ambientAutoPlayWithFocus")
        }
    }
    @Published private(set) var isMuted: Bool = false

    var isPlaying: Bool {
        !activeSounds.isEmpty && !isMuted
    }

    // Lock-free / lock-guarded state shared with the real-time audio render thread
    private let stateLock = NSLock()
    private var rtRainGain: Float = 0
    private var rtBrownGain: Float = 0
    private var rtVinylGain: Float = 0
    private var rtFireGain: Float = 0
    private var rtMasterGain: Float = 0.7

    // Procedural synthesis filter states (accessed only on the audio render thread)
    private var brownStateL: Float = 0
    private var brownStateR: Float = 0
    private var rainLP1L: Float = 0
    private var rainLP2L: Float = 0
    private var rainLP1R: Float = 0
    private var rainLP2R: Float = 0
    private var rainDropEnv: Float = 0
    private var vinylCrackL: Float = 0
    private var vinylCrackR: Float = 0
    private var fireRumbleL: Float = 0
    private var fireRumbleR: Float = 0
    private var firePopEnv: Float = 0
    private var sampleCounter: UInt64 = 0
    private var rngState: UInt64 = 0x853C49E6748FEA9B

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var pausedByTimer = Set<AmbientSound>()

    private init() {
        let defaults = UserDefaults.standard
        let savedMaster = defaults.object(forKey: "ambientMasterVolume") as? Float ?? 0.75
        self.masterVolume = min(max(savedMaster, 0), 1)
        self.autoPlayWithFocusTimer = defaults.object(forKey: "ambientAutoPlayWithFocus") as? Bool ?? true

        var initialVolumes: [AmbientSound: Float] = [:]
        for sound in AmbientSound.allCases {
            let key = "ambientVol_\(sound.rawValue)"
            let v = defaults.object(forKey: key) as? Float ?? sound.defaultVolume
            initialVolumes[sound] = min(max(v, 0), 1)
        }
        self.volumes = initialVolumes
        syncAtomicState()
    }

    func volume(for sound: AmbientSound) -> Float {
        volumes[sound] ?? sound.defaultVolume
    }

    func setVolume(_ value: Float, for sound: AmbientSound) {
        let clamped = min(max(value, 0), 1)
        volumes[sound] = clamped
        UserDefaults.standard.set(clamped, forKey: "ambientVol_\(sound.rawValue)")
        if clamped > 0.02 && !activeSounds.contains(sound) {
            activeSounds.insert(sound)
        } else if clamped <= 0.005 && activeSounds.contains(sound) {
            activeSounds.remove(sound)
        }
        syncAtomicState()
        updateEngineRunState()
    }

    func isActive(_ sound: AmbientSound) -> Bool {
        activeSounds.contains(sound)
    }

    func toggle(_ sound: AmbientSound) {
        if activeSounds.contains(sound) {
            activeSounds.remove(sound)
        } else {
            if (volumes[sound] ?? 0) < 0.05 {
                volumes[sound] = sound.defaultVolume
            }
            activeSounds.insert(sound)
            isMuted = false
        }
        saveLastPresetSelection()
        syncAtomicState()
        updateEngineRunState()
    }

    func toggleMuteAll() {
        if activeSounds.isEmpty {
            // Restore last active selection or default to Rain + Vinyl
            let saved = UserDefaults.standard.stringArray(forKey: "ambientLastSelection") ?? []
            let restored = Set(saved.compactMap(AmbientSound.init(rawValue:)))
            activeSounds = restored.isEmpty ? [.rain, .vinyl] : restored
            isMuted = false
        } else {
            isMuted.toggle()
        }
        syncAtomicState()
        updateEngineRunState()
    }

    func stopAll() {
        activeSounds.removeAll()
        pausedByTimer.removeAll()
        isMuted = false
        syncAtomicState()
        updateEngineRunState()
    }

    func applyPreset(_ sounds: Set<AmbientSound>) {
        activeSounds = sounds
        isMuted = false
        saveLastPresetSelection()
        syncAtomicState()
        updateEngineRunState()
    }

    // MARK: - Focus Timer Coordination

    func handleTimerStart(isFocusPhase: Bool) {
        guard autoPlayWithFocusTimer else { return }
        if isFocusPhase {
            if activeSounds.isEmpty {
                if !pausedByTimer.isEmpty {
                    activeSounds = pausedByTimer
                    pausedByTimer.removeAll()
                } else {
                    let saved = UserDefaults.standard.stringArray(forKey: "ambientLastSelection") ?? []
                    let restored = Set(saved.compactMap(AmbientSound.init(rawValue:)))
                    activeSounds = restored.isEmpty ? [.rain, .vinyl] : restored
                }
            }
            isMuted = false
            syncAtomicState()
            updateEngineRunState()
        } else {
            // Break phase: pause ambient sounds until next focus phase
            handleTimerPauseOrEnd()
        }
    }

    func handleTimerPauseOrEnd() {
        guard autoPlayWithFocusTimer, !activeSounds.isEmpty else { return }
        pausedByTimer = activeSounds
        activeSounds.removeAll()
        syncAtomicState()
        updateEngineRunState()
    }

    private func saveLastPresetSelection() {
        guard !activeSounds.isEmpty else { return }
        UserDefaults.standard.set(activeSounds.map(\.rawValue), forKey: "ambientLastSelection")
    }

    // MARK: - Audio Engine

    private func syncAtomicState() {
        let muted = isMuted
        let master = muted ? 0 : masterVolume
        let rain = activeSounds.contains(.rain) ? (volumes[.rain] ?? 0.65) : 0
        let brown = activeSounds.contains(.brownNoise) ? (volumes[.brownNoise] ?? 0.55) : 0
        let vinyl = activeSounds.contains(.vinyl) ? (volumes[.vinyl] ?? 0.45) : 0
        let fire = activeSounds.contains(.fireplace) ? (volumes[.fireplace] ?? 0.50) : 0

        stateLock.lock()
        rtMasterGain = master
        rtRainGain = rain
        rtBrownGain = brown
        rtVinylGain = vinyl
        rtFireGain = fire
        stateLock.unlock()
    }

    private func updateEngineRunState() {
        if isPlaying {
            startEngineIfNeeded()
        } else {
            stopEngine()
        }
    }

    private func startEngineIfNeeded() {
        if let engine, engine.isRunning { return }

        let newEngine = AVAudioEngine()
        let mainMixer = newEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48000)

        guard let renderFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 2,
            interleaved: false
        ) else { return }

        let node = AVAudioSourceNode(format: renderFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            return self.renderAudio(frameCount: Int(frameCount), sampleRate: sampleRate, audioBufferList: audioBufferList)
        }

        newEngine.attach(node)
        newEngine.connect(node, to: mainMixer, format: renderFormat)

        do {
            try newEngine.start()
            self.engine = newEngine
            self.sourceNode = node
        } catch {
            NSLog("OpenNotchi: AmbientSoundManager failed to start AVAudioEngine: \(error)")
        }
    }

    private func stopEngine() {
        engine?.stop()
        engine = nil
        sourceNode = nil
    }

    @inline(__always)
    private func nextWhiteNoise() -> Float {
        // Fast Xorshift64* PRNG in [-1, 1]
        var x = rngState
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        rngState = x
        let u = UInt32(truncatingIfNeeded: x &* 0x2545F4914F6CDD1D >> 32)
        return (Float(u) / Float(UInt32.max)) * 2.0 - 1.0
    }

    private func renderAudio(frameCount: Int, sampleRate: Float, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        stateLock.lock()
        let master = rtMasterGain
        let rainGain = rtRainGain
        let brownGain = rtBrownGain
        let vinylGain = rtVinylGain
        let fireGain = rtFireGain
        stateLock.unlock()

        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard abl.count >= 2,
              let outL = abl[0].mData?.assumingMemoryBound(to: Float.self),
              let outR = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
            return noErr
        }

        if master <= 0.001 || (rainGain + brownGain + vinylGain + fireGain) <= 0.001 {
            for i in 0..<frameCount {
                outL[i] = 0
                outR[i] = 0
            }
            return noErr
        }

        for i in 0..<frameCount {
            sampleCounter &+= 1
            var sampleL: Float = 0
            var sampleR: Float = 0

            // 1. Brown Noise (deep warm 1/f^2 cascade)
            if brownGain > 0.001 {
                let wL = nextWhiteNoise()
                let wR = nextWhiteNoise()
                brownStateL = (brownStateL + 0.018 * wL) / 1.018
                brownStateR = (brownStateR + 0.018 * wR) / 1.018
                let stereoBrownL = (brownStateL * 0.85 + brownStateR * 0.15) * 0.28 * brownGain
                let stereoBrownR = (brownStateR * 0.85 + brownStateL * 0.15) * 0.28 * brownGain
                sampleL += stereoBrownL
                sampleR += stereoBrownR
            }

            // 2. Midnight Rain (two-stage pink/bandpass + soft pattering droplet envelope)
            if rainGain > 0.001 {
                let wL = nextWhiteNoise()
                let wR = nextWhiteNoise()
                rainLP1L += 0.12 * (wL - rainLP1L)
                rainLP2L += 0.04 * (rainLP1L - rainLP2L)
                rainLP1R += 0.12 * (wR - rainLP1R)
                rainLP2R += 0.04 * (rainLP1R - rainLP2R)

                // Subtle raindrop patter modulation
                if nextWhiteNoise() > 0.9985 {
                    rainDropEnv = min(1.0, rainDropEnv + 0.35)
                }
                rainDropEnv *= 0.9965
                let patter = (rainLP1L - rainLP2L) * (0.65 + 0.35 * rainDropEnv)
                let patterR = (rainLP1R - rainLP2R) * (0.65 + 0.35 * rainDropEnv)

                sampleL += (rainLP2L * 0.14 + patter * 0.16) * rainGain
                sampleR += (rainLP2R * 0.14 + patterR * 0.16) * rainGain
            }

            // 3. Vinyl Crackle (warm analog floor + gentle dust micro-impulses)
            if vinylGain > 0.001 {
                let w = nextWhiteNoise()
                if w > 0.9992 {
                    let pop = (nextWhiteNoise() * 0.5 + 0.5) * 0.22
                    if (sampleCounter & 1) == 0 {
                        vinylCrackL += pop
                        vinylCrackR += pop * 0.4
                    } else {
                        vinylCrackR += pop
                        vinylCrackL += pop * 0.4
                    }
                }
                vinylCrackL *= 0.94
                vinylCrackR *= 0.94
                let warmFloor = sin(Float(sampleCounter) * 2.0 * .pi * 60.0 / sampleRate) * 0.003
                sampleL += (vinylCrackL + warmFloor + w * 0.004) * vinylGain
                sampleR += (vinylCrackR + warmFloor + w * 0.004) * vinylGain
            }

            // 4. Cozy Hearth / Fireplace (low hearth rumble + soft ember crackles)
            if fireGain > 0.001 {
                let wL = nextWhiteNoise()
                let wR = nextWhiteNoise()
                fireRumbleL = (fireRumbleL + 0.009 * wL) / 1.009
                fireRumbleR = (fireRumbleR + 0.009 * wR) / 1.009
                if wL > 0.9990 {
                    firePopEnv = min(1.0, firePopEnv + 0.5)
                }
                firePopEnv *= 0.988
                let emberL = wL * firePopEnv * 0.08
                let emberR = wR * firePopEnv * 0.08
                sampleL += (fireRumbleL * 0.22 + emberL) * fireGain
                sampleR += (fireRumbleR * 0.22 + emberR) * fireGain
            }

            // Soft-clipping limiter
            outL[i] = tanh(sampleL * master)
            outR[i] = tanh(sampleR * master)
        }

        return noErr
    }
}

