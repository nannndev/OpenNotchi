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
                    ForEach(MirrorEffect.allCases) { Text("\($0.displayName) · \($0.category)").tag($0) }
                }
                Picker("Background", selection: $settings.mirrorBackground) {
                    ForEach(MirrorBackground.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Self-Timer", selection: $settings.mirrorTimerSeconds) {
                    Text("Instant (0s)").tag(0)
                    Text("3 Seconds").tag(3)
                    Text("5 Seconds").tag(5)
                }
                Toggle("Keep the notch open while using the Mirror", isOn: $settings.mirrorStaysOpen)
                Toggle("Ring light", isOn: $settings.mirrorRingLight)
                Toggle("Composition grid (3×3)", isOn: $settings.mirrorGrid)
                Toggle("Mirror flip horizontal", isOn: $settings.mirrorFlipped)
                Toggle("Hand gestures: ✌️ photo, 👍 confetti, ✋ ring light", isOn: $settings.mirrorGestures)
                Text(
                    "Gestures and backgrounds are recognized on your Mac with Apple's Vision framework. Nothing leaves your Mac, and the camera only runs while the Mirror tab is open."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section("TikTok Camera Adjustments") {
                LabeledContent("Beauty Glow") {
                    Slider(value: $settings.mirrorGlow, in: 0.0...1.0)
                }
                LabeledContent("Brightness") {
                    Slider(value: $settings.mirrorBrightness, in: -0.4...0.4)
                }
                LabeledContent("Contrast") {
                    Slider(value: $settings.mirrorContrast, in: 0.6...1.5)
                }
                LabeledContent("Color Saturation") {
                    Slider(value: $settings.mirrorSaturation, in: 0.0...1.8)
                }
                LabeledContent("Warmth") {
                    Slider(value: $settings.mirrorWarmth, in: -1.0...1.0)
                }
                LabeledContent("Vignette") {
                    Slider(value: $settings.mirrorVignette, in: 0.0...1.0)
                }
                LabeledContent("Camera Zoom (\(String(format: "%.1fx", settings.mirrorZoom)))") {
                    Slider(value: $settings.mirrorZoom, in: 1.0...2.5)
                }
                if settings.cameraAdjustments.isModified {
                    Button("Reset Camera Adjustments") {
                        settings.resetCameraAdjustments()
                    }
                }
            }
        }
        .task { cameras = await Task.detached { CameraPreview.cameras }.value }
    }
}
