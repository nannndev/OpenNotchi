import AVFoundation
import SwiftUI

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
                PrompterEditor(scriptDraft: $scriptDraft) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scrollOffset = 0
                        isEditing = false
                    }
                }
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
            EyeContactGuide()

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

                        ForEach(
                            Array(settings.prompterScript.components(separatedBy: "\n\n").enumerated()), id: \.offset
                        ) { _, para in
                            Text(para)
                                .font(
                                    .system(size: CGFloat(settings.prompterFontSize), weight: .bold, design: .rounded)
                                )
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
                                scrollOffset = max(
                                    0, min(estimatedContentHeight + 60, scrollOffset - value.translation.height * 0.18))
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
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            PrompterToolbar(
                isPlaying: isPlaying,
                wordsCount: wordsCount,
                estimatedDuration: estimatedDuration,
                onTogglePlay: togglePlayback,
                onRewind: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scrollOffset = 0
                    }
                },
                onEdit: {
                    scriptDraft = settings.prompterScript
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPlaying = false
                        isEditing = true
                    }
                }
            )
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
