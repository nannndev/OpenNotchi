import AVFoundation
import SwiftUI

struct MirrorPane: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var cameras: [AVCaptureDevice] = []

    var body: some View {
        Form {
            Section("Photobox") {
                PhotoboxSettings()
            }
            Section("Mirror") {
                Picker("Camera Device", selection: $settings.mirrorCameraID) {
                    Text("Automatic (Default)").tag("")
                    ForEach(cameras, id: \.uniqueID) { camera in
                        Text(camera.localizedName).tag(camera.uniqueID)
                    }
                }
                if AVCaptureDevice.authorizationStatus(for: .video) == .denied
                    || AVCaptureDevice.authorizationStatus(for: .video) == .restricted
                {
                    HStack {
                        Label(
                            "Camera access is disabled in macOS Privacy Settings.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        .font(.caption)
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                        }
                        .controlSize(.small)
                    }
                }
                Picker("Look", selection: $settings.mirrorEffect) {
                    ForEach(MirrorEffect.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Background", selection: $settings.mirrorBackground) {
                    ForEach(MirrorBackground.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Keep the notch open while using the Mirror", isOn: $settings.mirrorStaysOpen)
                Toggle("Ring light", isOn: $settings.mirrorRingLight)
                Toggle("Hand gestures: ✌️ photo, 👍 confetti, ✋ ring light", isOn: $settings.mirrorGestures)
                Text(
                    "Gestures and backgrounds are recognized on your Mac with Apple's Vision framework. Nothing leaves your Mac, and the camera only runs while the Mirror tab is open."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .task { cameras = await Task.detached { CameraPreview.cameras }.value }
    }
}
