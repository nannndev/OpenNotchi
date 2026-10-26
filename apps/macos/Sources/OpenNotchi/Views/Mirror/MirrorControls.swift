import SwiftUI

/// Looks, portrait blur, ring light, gestures and the camera picker, shown while the pointer is over the mirror.
struct MirrorControls: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MirrorEffect.allCases) { effect in
                let selected = settings.mirrorEffect == effect
                Button {
                    settings.mirrorEffect = effect
                } label: {
                    Circle()
                        .fill(LinearGradient(colors: effect.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white, lineWidth: selected ? 2 : 0).padding(-3))
                }
                .buttonStyle(.plain)
                .help(effect.displayName)
            }

            Text(settings.mirrorEffect.displayName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 46, alignment: .leading)
                .padding(.leading, 2)

            Divider().frame(height: 16)

            Menu {
                Picker("Background", selection: $settings.mirrorBackground) {
                    ForEach(MirrorBackground.allCases) { Label($0.displayName, systemImage: $0.icon).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: settings.mirrorBackground.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settings.mirrorBackground == .none ? .white : .cyan)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Background: \(settings.mirrorBackground.displayName)")

            Menu {
                Picker("Photobox strip", selection: $settings.stripStyle) {
                    ForEach(StripStyle.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: settings.stripStyle.swatch, startPoint: .top, endPoint: .bottom))
                    .frame(width: 11, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.7), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Photobox strip: \(settings.stripStyle.displayName)")
            toggle(isOn: $settings.mirrorRingLight, on: "light.max", off: "light.min", tint: .yellow, help: "Ring light")
            toggle(isOn: $settings.mirrorGestures, on: "hand.raised.fill", off: "hand.raised.slash", tint: .green, help: "Hand gestures: ✌️ photo, 👍 confetti, ✋ ring light")

            let cameras = CameraPreview.cameras
            if cameras.count > 1 {
                Menu {
                    ForEach(cameras, id: \.uniqueID) { camera in
                        Button {
                            settings.mirrorCameraID = camera.uniqueID
                        } label: {
                            if camera.uniqueID == settings.mirrorCameraID {
                                Label(camera.localizedName, systemImage: "checkmark")
                            } else {
                                Text(camera.localizedName)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Camera")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.55)))
        .background(Capsule().fill(.ultraThinMaterial))
    }

    private func toggle(isOn: Binding<Bool>, on: String, off: String, tint: Color, help: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: isOn.wrappedValue ? on : off)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? tint : .white)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Grabber under the mirror: drag to make the notch taller, double-click to toggle short and tall.
struct ResizeHandle: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var vm: NotchViewModel
    @State private var startHeight: Double?
    @State private var isHovering = false

    var body: some View {
        Capsule()
            .fill(.white.opacity(isHovering || startHeight != nil ? 0.6 : 0.25))
            .frame(width: isHovering || startHeight != nil ? 54 : 40, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 10)
            .contentShape(Rectangle())
            .onHover { inside in
                withAnimation(.easeInOut(duration: 0.15)) { isHovering = inside }
                inside ? NSCursor.resizeUpDown.push() : NSCursor.pop()
            }
            .gesture(
                // Global coordinates, because the view itself moves as the notch grows.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = startHeight ?? vm.openSize.height
                        if startHeight == nil {
                            startHeight = start
                            vm.isResizing = true
                        }
                        settings.mirrorHeight = clamp(start + value.translation.height)
                    }
                    .onEnded { _ in
                        startHeight = nil
                        vm.isResizing = false
                    }
            )
            .onTapGesture(count: 2) {
                let tall = settings.mirrorHeight > (NotchViewModel.defaultOpenHeight + NotchViewModel.maxOpenHeight) / 2.0
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    settings.mirrorHeight = tall ? NotchViewModel.defaultOpenHeight : NotchViewModel.maxOpenHeight
                }
            }
            .help("Drag to resize · double-click to toggle")
    }

    private func clamp(_ height: Double) -> Double {
        min(max(height, NotchViewModel.defaultOpenHeight), NotchViewModel.maxOpenHeight)
    }
}
