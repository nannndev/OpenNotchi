import AppKit
import AVFoundation
import SwiftUI

/// Sheet for recording a short webcam video clip to use as the background for lyric videos.
struct CameraVideoRecordSheet: View {
    let onRecordFinished: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorder = CameraRecorderModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                CameraPreview(
                    effect: settings.mirrorEffect,
                    adjustments: settings.cameraAdjustments,
                    ringLight: settings.mirrorRingLight,
                    cameraID: settings.mirrorCameraID
                )
                .frame(width: 480, height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(recorder.isRecording ? Color.red : Color.white.opacity(0.15), lineWidth: recorder.isRecording ? 3 : 1)
                )

                if recorder.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                        Text(String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(14)
                }
            }

            // Filter Strip for Video Preview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MirrorEffect.allCases) { effect in
                        let selected = settings.mirrorEffect == effect
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.mirrorEffect = effect
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(LinearGradient(colors: effect.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 14, height: 14)
                                Text(effect.displayName)
                                    .font(.system(size: 11, weight: selected ? .bold : .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(selected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 480)

            HStack(spacing: 14) {
                Button("Cancel") {
                    recorder.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if !recorder.isRecording {
                    Button {
                        startRecording()
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 12, height: 12)
                            Text("Start Recording")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        stopRecording()
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle().fill(Color.white).frame(width: 10, height: 10)
                            Text("Stop & Use Video")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .onDisappear {
            timer?.invalidate()
            recorder.cleanup()
        }
    }

    private func startRecording() {
        elapsedSeconds = 0
        recorder.startRecording()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        recorder.stopRecording { url in
            if let url = url {
                onRecordFinished(url)
                dismiss()
            }
        }
    }
}

final class CameraRecorderModel: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var isRecording = false

    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var completion: ((URL?) -> Void)?
    private var tempFileURL: URL?

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        let cameraID = AppSettings.shared.mirrorCameraID
        let device = CameraPreview.cameras.first { $0.uniqueID == cameraID }
            ?? AVCaptureDevice.default(for: .video)

        if let device = device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("opennotchi_rec_\(UUID().uuidString).mov")
        tempFileURL = fileURL

        try? FileManager.default.removeItem(at: fileURL)

        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        movieOutput.stopRecording()
    }

    func cancel() {
        movieOutput.stopRecording()
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func cleanup() {
        session.stopRunning()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            if error == nil {
                self.completion?(outputFileURL)
            } else {
                self.completion?(nil)
            }
            self.completion = nil
        }
    }
}
