import SwiftUI

struct PhotoboxButton: View {
    @EnvironmentObject private var settings: AppSettings
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.black.opacity(0.5)))
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.4), radius: 6)
        }
        .buttonStyle(.plain)
        .help("Photobox: 4 shots in a \(settings.stripStyle.displayName) strip")
    }
}

struct ShutterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(.white, lineWidth: 3).frame(width: 38, height: 38)
                Circle().fill(.white).frame(width: 29, height: 29)
            }
            .shadow(color: .black.opacity(0.4), radius: 6)
        }
        .buttonStyle(.plain)
        .help("Take a photo (or show ✌️)")
    }
}
