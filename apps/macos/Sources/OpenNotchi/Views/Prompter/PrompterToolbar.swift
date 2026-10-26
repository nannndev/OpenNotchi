import SwiftUI

/// Bottom bar of the teleprompter: playback, speed, font size and display toggles.
struct PrompterToolbar: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent

    let isPlaying: Bool
    let wordsCount: Int
    let estimatedDuration: TimeInterval
    let onTogglePlay: () -> Void
    let onRewind: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            playButton
            rewindButton
            statsPill
            Spacer(minLength: 4)
            speedControl
            fontSizeControl
            heightToggle
            cameraToggle
            pinToggle
            editButton
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

    private var playButton: some View {
        Button {
            onTogglePlay()
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
    }

    private var rewindButton: some View {
        Button {
            onRewind()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help("Rewind to top (R)")
    }

    private var statsPill: some View {
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
    }

    private var speedControl: some View {
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
    }

    private var fontSizeControl: some View {
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
    }

    private var heightToggle: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                settings.prompterHeight = settings.prompterHeight > 280 ? 250 : 330
            }
        } label: {
            Image(
                systemName: settings.prompterHeight > 280
                    ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
            )
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 25, height: 25)
            .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help(settings.prompterHeight > 280 ? "Switch to compact height" : "Expand taller for more reading room")
    }

    private var cameraToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                settings.prompterShowCameraPreview.toggle()
            }
        } label: {
            Image(systemName: settings.prompterShowCameraPreview ? "camera.fill" : "camera")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(settings.prompterShowCameraPreview ? accent.color : .white.opacity(0.8))
                .frame(width: 25, height: 25)
                .background(
                    Circle().fill(
                        settings.prompterShowCameraPreview ? accent.color.opacity(0.2) : Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help(
            settings.prompterShowCameraPreview
                ? "Hide camera rehearsal preview" : "Show camera rehearsal preview behind text")
    }

    private var pinToggle: some View {
        Button {
            settings.prompterStaysOpen.toggle()
        } label: {
            Image(systemName: settings.prompterStaysOpen ? "pin.fill" : "pin")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(settings.prompterStaysOpen ? .yellow : .white.opacity(0.8))
                .frame(width: 25, height: 25)
                .background(
                    Circle().fill(settings.prompterStaysOpen ? Color.yellow.opacity(0.2) : Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help("Keep teleprompter floating above all windows during calls")
    }

    private var editButton: some View {
        Button {
            onEdit()
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
}
