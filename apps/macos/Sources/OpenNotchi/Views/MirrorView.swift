import AVFoundation
import SwiftUI

struct MirrorView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var vm: NotchViewModel
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            CameraPreview(effect: settings.mirrorEffect, ringLight: settings.mirrorRingLight, cameraID: settings.mirrorCameraID)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    // Ring light: a soft white glow around the edge, like the real thing.
                    if settings.mirrorRingLight {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                            .blur(radius: 4)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.5), lineWidth: 1))
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .bottom) {
                    MirrorControls()
                        .padding(8)
                        .opacity(isHovering ? 1 : 0)
                }
                .shadow(color: settings.mirrorRingLight ? .white.opacity(0.35) : .clear, radius: 12)
                .onHover { inside in
                    withAnimation(.easeInOut(duration: 0.2)) { isHovering = inside }
                }
                .animation(.easeInOut(duration: 0.25), value: settings.mirrorRingLight)

            ResizeHandle()
        }
    }
}

/// Effect swatches, ring light and camera picker, shown while the pointer is over the mirror.
private struct MirrorControls: View {
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

            Button {
                settings.mirrorRingLight.toggle()
            } label: {
                Image(systemName: settings.mirrorRingLight ? "light.max" : "light.min")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settings.mirrorRingLight ? .yellow : .white)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Ring light")

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
}

/// Grabber under the mirror: drag to make the notch taller, double-click to toggle short and tall.
private struct ResizeHandle: View {
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
                let tall = settings.mirrorHeight > (NotchViewModel.defaultOpenHeight + NotchViewModel.maxOpenHeight) / 2
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
