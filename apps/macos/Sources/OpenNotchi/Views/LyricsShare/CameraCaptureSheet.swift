import AppKit
import SwiftUI

struct CameraCaptureSheet: View {
    let onCapture: (NSImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @State private var request = 0

    var body: some View {
        VStack(spacing: 12) {
            CameraPreview(
                effect: settings.mirrorEffect,
                adjustments: settings.cameraAdjustments,
                ringLight: settings.mirrorRingLight,
                cameraID: settings.mirrorCameraID,
                captureRequest: request,
                onCapture: { photo in
                    onCapture(NSImage(cgImage: photo, size: NSSize(width: photo.width, height: photo.height)))
                    dismiss()
                }
            )
            .frame(width: 480, height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Quick Filter Selector Strip
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
