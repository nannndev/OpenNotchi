import SwiftUI

/// Small round button on the artwork that switches Home into lyrics mode.
struct LyricsToggle: View {
    @Binding var isOn: Bool
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button { isOn.toggle() } label: {
            Image(systemName: isOn ? "quote.bubble.fill" : "quote.bubble")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? (accent.isNeutral ? .black : .white) : .white)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(isOn ? AnyShapeStyle(accent.isNeutral ? .white : accent.color) : AnyShapeStyle(.black.opacity(0.55)))
                )
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                .scaleEffect(hovering ? 1.1 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Show player" : "Show lyrics")
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25), value: hovering)
    }
}
