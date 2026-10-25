import AppKit
import SwiftUI

struct CameraCaptureSheet: View {
    let onCapture: (NSImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var request = 0

    var body: some View {
        VStack(spacing: 14) {
            CameraPreview(
                cameraID: AppSettings.shared.mirrorCameraID,
                captureRequest: request,
                onCapture: { photo in
                    onCapture(NSImage(cgImage: photo, size: NSSize(width: photo.width, height: photo.height)))
                    dismiss()
                }
            )
            .frame(width: 480, height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button { request += 1 } label: { Label("Take Photo", systemImage: "camera.fill") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
    }
}
