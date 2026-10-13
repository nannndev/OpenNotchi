import AVFoundation
import SwiftUI

/// Preset teleprompter scripts for fast rehearsal and presentations.
struct PrompterTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let script: String
}

enum PrompterPresets {
    static let all: [PrompterTemplate] = [
        PrompterTemplate(
            title: "Elevator Pitch (30s)",
            icon: "bolt.fill",
            script: """
            Hi everyone, thank you for your time today!

            [Look right at this camera line — your gaze is 100% natural]

            OpenNotchi transforms your MacBook notch into a living, intelligent dynamic hub.

            From spinning turntable vinyl decks with haptic grooves, to synced karaoke lyrics, developer tools, and this real-time eye-contact teleprompter — it turns unused screen space into your favorite daily companion.

            It's lightweight, open source, and built natively with Swift and Metal.

            I'd love to show you a quick demo right now!
            """
        ),
        PrompterTemplate(
            title: "Daily Standup Update",
            icon: "person.3.fill",
            script: """
            Good morning team! Here's a quick update on my end:

            [Keep your eyes pinned to the camera lens above]

            Yesterday:
            • Finalized the new release pipeline and resolved all CI edge cases.
            • Polished the audio routing and developer tools tab.

            Today:
            • Integrating the new eye-contact teleprompter for video meetings.
            • Running regression tests and publishing the latest universal build.

            Blockers:
            • None on my side. All green and ready to roll!
            """
        ),
        PrompterTemplate(
            title: "Product Walkthrough",
            icon: "macbook",
            script: """
            Welcome everyone to today's feature demonstration!

            Over the next few minutes, we're exploring our most requested capability: the Camera Eye-Contact Teleprompter.

            Notice how natural my eye contact feels right now. Instead of glancing down at notes or looking off to a second monitor, my script scrolls right under the webcam lens.

            You can adjust scrolling speed on the fly, switch between stealth frosted glass and camera preview, and paste your own meeting notes in seconds.

            Let's dive into the live walkthrough!
            """
        ),
        PrompterTemplate(
            title: "Job Interview Intro",
            icon: "briefcase.fill",
            script: """
            Thank you so much for the invitation to speak with you today!

            [Smile and maintain steady eye contact with the camera]

            My background centers around building high-impact software experiences with an obsessive focus on performance, intuitive design, and clean architecture.

            Over the past few years, I've led projects from zero to production — working with Swift, macOS system frameworks, and modern full-stack web applications.

            What excites me most about this role is the opportunity to solve hard problems alongside a world-class team.

            I'm looking forward to diving into the details today!
            """
        ),
        PrompterTemplate(
            title: "Keynote / Speech Opening",
            icon: "sparkles",
            script: """
            Good afternoon, everyone!

            Have you ever noticed how disconnected virtual meetings feel when people keep looking down at their notes?

            Today, we are changing that.

            Technology should work for us, not distract us. By placing your thoughts right where your audience is looking, communication becomes effortless, authentic, and engaging.

            Let's take a closer look at what we've built together.
            """
        )
    ]
}

struct PrompterView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var vm: NotchViewModel
    @Environment(\.notchAccent) private var accent

    @State private var isPlaying = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isEditing = false
    @State private var scriptDraft = ""
    @State private var lastTick: Date? = nil

    private var wordsCount: Int {
        settings.prompterScript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private var estimatedWPM: Int {
        // Calibrated baseline: 28 pt/s is approx 135 WPM at 18pt font
        Int(max(50, min(350, (settings.prompterScrollSpeed / 28.0) * 135.0)))
    }

    private var estimatedDuration: TimeInterval {
        let wpm = Double(estimatedWPM)
        return max(5, (Double(wordsCount) / wpm) * 60.0)
    }

    private var estimatedContentHeight: CGFloat {
        max(350, CGFloat(wordsCount * 6 + 180))
    }

    var body: some View {
        ZStack {
            // Optional camera rehearsal backdrop
            if settings.prompterShowCameraPreview {
                CameraPreview(
                    effect: .natural,
                    ringLight: false,
                    background: .none,
                    artwork: nil,
                    musicPlaying: false,
                    gesturesEnabled: false,
                    cameraID: settings.mirrorCameraID,
                    captureRequest: 0,
                    onGesture: { _ in },
                    onCapture: { _ in }
                )
                .opacity(0.42)
                .overlay(Color.black.opacity(0.60))
            } else {
                Color.black.opacity(settings.prompterOpacity)
            }

            if isEditing {
                editorView
            } else {
                teleprompterReadingView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            scriptDraft = settings.prompterScript
            scrollOffset = 0
            isPlaying = false
            lastTick = nil
        }
        .onDisappear {
            isPlaying = false
            lastTick = nil
        }
    }

    // MARK: - Teleprompter Reading View

    private var teleprompterReadingView: some View {
        VStack(spacing: 0) {
            // Top Eye-Contact Zone Banner
            eyeContactTargetGuide

            // Scrolling Viewport
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    // Trackpad wheel scroll receiver
                    VerticalWheelScrollHelper { delta in
                        isPlaying = false
                        scrollOffset = max(0, min(estimatedContentHeight + 60, scrollOffset - delta * 1.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Eye-level Reading Focus Lens Band
                    Rectangle()
                        .fill(accent.color.opacity(0.08))
                        .frame(height: CGFloat(settings.prompterFontSize * 1.85))
                        .overlay(
                            Rectangle()
                                .stroke(accent.color.opacity(0.22), lineWidth: 0.8)
                        )
                        .offset(y: 8)
                        .allowsHitTesting(false)

                    // Continuous Scrolling Text
                    VStack(alignment: .center, spacing: 18) {
                        // Top spacing so the first line starts comfortably at the Eye-Contact band
                        Color.clear.frame(height: 10)

                        ForEach(Array(settings.prompterScript.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, para in
                            Text(para)
                                .font(.system(size: CGFloat(settings.prompterFontSize), weight: .bold, design: .rounded))
                                .lineSpacing(CGFloat(settings.prompterFontSize * 0.36))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.95), radius: 3, x: 0, y: 1)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        // End-of-script indicator
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(accent.color)
                                Text("End of Script")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    scrollOffset = 0
                                }
                            } label: {
                                Text("Restart from Top (↺)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(accent.color)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 20)

                        // Bottom padding
                        Color.clear.frame(height: geo.size.height + 40)
                    }
                    .padding(.horizontal, 48)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(y: -scrollOffset)
                    .scaleEffect(x: settings.prompterMirrorText ? -1 : 1, y: 1)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isPlaying = false
                                scrollOffset = max(0, min(estimatedContentHeight + 60, scrollOffset - value.translation.height * 0.18))
                            }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                // Top and bottom fade mask
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.82),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Bottom Floating Controls Toolbar
            controlToolbar
        }
        // Continuous animation driver
        .overlay {
            if isPlaying {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Color.clear
                        .onChange(of: timeline.date) { _, newDate in
                            tickScroll(at: newDate)
                        }
                }
            }
        }
    }

    // MARK: - Eye-Contact Target Guide

    private var eyeContactTargetGuide: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, accent.color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.5)

            HStack(spacing: 5) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(accent.color)

                Text("EYE-CONTACT LEVEL")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Image(systemName: "arrow.up")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(accent.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .overlay(Capsule().stroke(accent.color.opacity(0.7), lineWidth: 1))
            .shadow(color: accent.color.opacity(0.4), radius: 6)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.color.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.5)
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Bottom Control Toolbar

    private var controlToolbar: some View {
        HStack(spacing: 8) {
            // Play / Pause Button
            Button {
                togglePlayback()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(isPlaying ? "Pause" : "Play")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(isPlaying ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isPlaying ? accent.color : Color.white.opacity(0.18))
                )
                .overlay(
                    Capsule().stroke(isPlaying ? Color.white.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 0.8)
                )
                .shadow(color: isPlaying ? accent.color.opacity(0.5) : .clear, radius: 6)
            }
            .buttonStyle(.plain)
            .help(isPlaying ? "Pause scroll (Space)" : "Start auto-scroll (Space)")

            // Rewind to Top Button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    scrollOffset = 0
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("Rewind to top (R)")

            // Progress & WPM Metric Pill
            HStack(spacing: 4) {
                Text("\(wordsCount) wds")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Text("·")
                    .foregroundStyle(.white.opacity(0.35))

                Text(formatCountdown(estimatedDuration))
                    .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.08)))

            Spacer(minLength: 4)

            // Speed Control with Presets & Steppers
            HStack(spacing: 3) {
                Button {
                    settings.prompterScrollSpeed = max(8, settings.prompterScrollSpeed - 2)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8.5, weight: .bold))
                        .frame(width: 18, height: 20)
                }
                .buttonStyle(.plain)

                Menu {
                    Section("Speed Presets") {
                        Button("🐢 16 pt/s · Santai (~80 WPM)") { settings.prompterScrollSpeed = 16 }
                        Button("🚶 26 pt/s · Normal (~130 WPM)") { settings.prompterScrollSpeed = 26 }
                        Button("🏃 38 pt/s · Sedang (~180 WPM)") { settings.prompterScrollSpeed = 38 }
                        Button("⚡ 52 pt/s · Cepat (~240 WPM)") { settings.prompterScrollSpeed = 52 }
                        Button("🚀 68 pt/s · Kilat (~300 WPM)") { settings.prompterScrollSpeed = 68 }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("\(Int(settings.prompterScrollSpeed)) pt/s")
                            .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(minWidth: 54)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Button {
                    settings.prompterScrollSpeed = min(90, settings.prompterScrollSpeed + 2)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8.5, weight: .bold))
                        .frame(width: 18, height: 20)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .help("Scroll speed (Click for presets)")

            // Font Size Stepper
            HStack(spacing: 2) {
                Button {
                    settings.prompterFontSize = max(13, settings.prompterFontSize - 2)
                } label: {
                    Text("A-")
                        .font(.system(size: 8.5, weight: .bold))
                        .frame(width: 18, height: 20)
                }
                .buttonStyle(.plain)

                Text("\(Int(settings.prompterFontSize))")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(width: 18)

                Button {
                    settings.prompterFontSize = min(36, settings.prompterFontSize + 2)
                } label: {
                    Text("A+")
                        .font(.system(size: 9.5, weight: .bold))
                        .frame(width: 18, height: 20)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .help("Font size")

            // Height Toggle (Compact vs Comfortable)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    settings.prompterHeight = settings.prompterHeight > 280 ? 250 : 330
                }
            } label: {
                Image(systemName: settings.prompterHeight > 280 ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 25, height: 25)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(settings.prompterHeight > 280 ? "Switch to compact height" : "Expand taller for more reading room")

            // Camera Rehearsal Preview Toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    settings.prompterShowCameraPreview.toggle()
                }
            } label: {
                Image(systemName: settings.prompterShowCameraPreview ? "camera.fill" : "camera")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(settings.prompterShowCameraPreview ? accent.color : .white.opacity(0.8))
                    .frame(width: 25, height: 25)
                    .background(Circle().fill(settings.prompterShowCameraPreview ? accent.color.opacity(0.2) : Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help(settings.prompterShowCameraPreview ? "Hide camera rehearsal preview" : "Show camera rehearsal preview behind text")

            // Pin / Stay Open Toggle
            Button {
                settings.prompterStaysOpen.toggle()
            } label: {
                Image(systemName: settings.prompterStaysOpen ? "pin.fill" : "pin")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(settings.prompterStaysOpen ? .yellow : .white.opacity(0.8))
                    .frame(width: 25, height: 25)
                    .background(Circle().fill(settings.prompterStaysOpen ? Color.yellow.opacity(0.2) : Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("Keep teleprompter floating above all windows during calls")

            // Edit Script Button
            Button {
                scriptDraft = settings.prompterScript
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPlaying = false
                    isEditing = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9.5, weight: .bold))
                    Text("Edit")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .help("Edit or paste custom script")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.8))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 7)
    }

    // MARK: - Editor View

    private var editorView: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent.color)
                    Text("Edit Script")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                // Preset Templates Menu
                Menu {
                    Section("Quick Templates") {
                        ForEach(PrompterPresets.all) { template in
                            Button {
                                scriptDraft = template.script
                            } label: {
                                Label(template.title, systemImage: template.icon)
                            }
                        }
                    }
                    Divider()
                    Button("Clear Script") {
                        scriptDraft = ""
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("Templates")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .foregroundStyle(.white)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                // Save & Done Button
                Button {
                    settings.prompterScript = scriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? PrompterPresets.all[0].script
                        : scriptDraft
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scrollOffset = 0
                        isEditing = false
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(accent.color))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // Text Editor
            TextEditor(text: $scriptDraft)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .lineSpacing(4)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.14), lineWidth: 1))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .background(Color.black.opacity(0.85))
    }

    // MARK: - Animation Engine

    private func togglePlayback() {
        if isPlaying {
            isPlaying = false
            lastTick = nil
        } else {
            if scrollOffset >= estimatedContentHeight {
                scrollOffset = 0
            }
            lastTick = Date()
            isPlaying = true
        }
    }

    private func tickScroll(at date: Date) {
        guard let last = lastTick else {
            lastTick = date
            return
        }
        let delta = max(0, min(0.1, date.timeIntervalSince(last)))
        lastTick = date

        let speed = CGFloat(settings.prompterScrollSpeed)
        let newOffset = scrollOffset + CGFloat(delta) * speed

        if newOffset >= estimatedContentHeight + 40 {
            // End of script reached
            isPlaying = false
            lastTick = nil
        } else {
            scrollOffset = newOffset
        }
    }
}

/// Helper to catch vertical trackpad scroll wheel events directly onto the teleprompter.
private struct VerticalWheelScrollHelper: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> WheelCatcher {
        WheelCatcher(onScroll: onScroll)
    }

    func updateNSView(_ nsView: WheelCatcher, context: Context) {
        nsView.onScroll = onScroll
    }

    class WheelCatcher: NSView {
        var onScroll: (CGFloat) -> Void

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func scrollWheel(with event: NSEvent) {
            if event.scrollingDeltaY != 0 {
                let delta = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
                onScroll(delta)
            } else {
                super.scrollWheel(with: event)
            }
        }
    }
}
