import SwiftUI

/// The "eye-contact level" banner at the top of the teleprompter, right under the camera.
struct EyeContactGuide: View {
    @Environment(\.notchAccent) private var accent

    var body: some View {
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
}
