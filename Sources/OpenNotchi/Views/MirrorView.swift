import SwiftUI

struct MirrorView: View {
    var body: some View {
        CameraPreview()
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomLeading) {
                Label("Mirror", systemImage: "camera.fill")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .padding(8)
            }
    }
}
