import AVFoundation
import SwiftUI

enum CameraAdjustParam: String, CaseIterable, Identifiable {
    case brightness = "Bright"
    case glow = "Glow"
    case contrast = "Contrast"
    case saturation = "Color"
    case warmth = "Warmth"
    case vignette = "Vignette"
    case zoom = "Zoom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .brightness: return "sun.max.fill"
        case .glow: return "sparkles"
        case .contrast: return "circle.lefthalf.filled"
        case .saturation: return "drop.fill"
        case .warmth: return "thermometer.sun.fill"
        case .vignette: return "camera.aperture"
        case .zoom: return "plus.magnifyingglass"
        }
    }
}

/// TikTok-style filter carousel, real-time beauty/color adjustments drawer, and studio controls.
struct MirrorControls: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var cameras: [AVCaptureDevice] = []
    @State private var showAdjustments = false
    @State private var selectedParam: CameraAdjustParam = .glow

    var body: some View {
        VStack(spacing: 6) {
            if showAdjustments {
                adjustmentsDrawer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 6) {
                // Scrollable TikTok-style filter strip
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(MirrorEffect.allCases) { effect in
                                let selected = settings.mirrorEffect == effect
                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        settings.mirrorEffect = effect
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(LinearGradient(colors: effect.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 16, height: 16)
                                            .overlay(
                                                Circle()
                                                    .stroke(.white, lineWidth: selected ? 1.8 : 0.5)
                                                    .opacity(selected ? 1 : 0.35)
                                            )
                                        Text(effect.displayName)
                                            .font(.system(size: 10, weight: selected ? .bold : .medium))
                                            .foregroundStyle(selected ? .white : .white.opacity(0.75))
                                    }
                                    .padding(.leading, 4)
                                    .padding(.trailing, 7)
                                    .padding(.vertical, 3.5)
                                    .background(
                                        Capsule()
                                            .fill(selected ? .white.opacity(0.22) : .white.opacity(0.06))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(.white.opacity(selected ? 0.45 : 0), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(effect.id)
                                .help("\(effect.displayName) (\(effect.category))")
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .frame(maxWidth: 270)
                    .onChange(of: settings.mirrorEffect) { _, newEffect in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(newEffect.id, anchor: .center)
                        }
                    }
                }

                Divider().frame(height: 16)

                // TikTok Adjust Drawer Toggle
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        showAdjustments.toggle()
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(showAdjustments || settings.cameraAdjustments.isModified ? .cyan : .white)
                            .frame(width: 24, height: 22)
                            .background(
                                Circle()
                                    .fill(showAdjustments ? Color.cyan.opacity(0.22) : .clear)
                            )
                        if settings.cameraAdjustments.isModified {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 5, height: 5)
                                .offset(x: -1, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Adjust beauty, lighting & color")

                // Background Segmentation Picker
                Menu {
                    Picker("Background", selection: $settings.mirrorBackground) {
                        ForEach(MirrorBackground.allCases) { Label($0.displayName, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: settings.mirrorBackground.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(settings.mirrorBackground == .none ? .white : .cyan)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Background: \(settings.mirrorBackground.displayName)")

                // Photobox Strip Style Picker
                Menu {
                    Picker("Photobox strip", selection: $settings.stripStyle) {
                        ForEach(StripStyle.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: settings.stripStyle.swatch, startPoint: .top, endPoint: .bottom))
                        .frame(width: 11, height: 17)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.75), lineWidth: 1))
                        .frame(width: 20, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Photobox strip: \(settings.stripStyle.displayName)")

                toggle(isOn: $settings.mirrorRingLight, on: "light.max", off: "light.min", tint: .yellow, help: "Ring light")
                toggle(isOn: $settings.mirrorGrid, on: "squareshape.split.3x3", off: "squareshape.split.3x3", tint: .cyan, help: "Composition grid")
                toggle(isOn: $settings.mirrorFlipped, on: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", off: "arrow.left.and.right.righttriangle.left.righttriangle.right", tint: .orange, help: "Mirror flip horizontal")
                toggle(isOn: $settings.mirrorGestures, on: "hand.raised.fill", off: "hand.raised.slash", tint: .green, help: "Hand gestures: ✌️ photo, 👍 confetti, ✋ ring light")

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
                            .frame(width: 22, height: 22)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Switch camera")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.black.opacity(0.6)))
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.8))
        }
        // Listing cameras can block for seconds inside CoreMediaIO; on the main thread that froze the whole notch.
        .task { cameras = await Task.detached { CameraPreview.cameras }.value }
    }

    // MARK: - TikTok Style Adjustments Drawer

    private var adjustmentsDrawer: some View {
        VStack(spacing: 6) {
            // Parameter selector pills
            HStack(spacing: 4) {
                ForEach(CameraAdjustParam.allCases) { param in
                    let active = selectedParam == param
                    let modified = isParamModified(param)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedParam = param
                        }
                    } label: {
                        HStack(spacing: 3.5) {
                            Image(systemName: param.icon)
                                .font(.system(size: 9, weight: .semibold))
                            Text(param.rawValue)
                                .font(.system(size: 9.5, weight: active ? .bold : .medium))
                            if modified {
                                Circle()
                                    .fill(active ? .white : .cyan)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(active ? Color.cyan.opacity(0.32) : .white.opacity(0.07))
                        )
                        .foregroundStyle(active ? .white : .white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }

                if settings.cameraAdjustments.isModified {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            settings.resetCameraAdjustments()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9, weight: .bold))
                            Text("Reset")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Color.red.opacity(0.25)))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Reset all camera adjustments")
                }
            }

            // Active slider row
            HStack(spacing: 8) {
                Image(systemName: selectedParam.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 16)

                Slider(
                    value: binding(for: selectedParam),
                    in: range(for: selectedParam)
                )
                .controlSize(.small)
                .tint(.cyan)
                .frame(width: 220)

                Text(formattedValue(for: selectedParam))
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 40, alignment: .trailing)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        resetParam(selectedParam)
                    }
                } label: {
                    Image(systemName: "gobackward")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(isParamModified(selectedParam) ? 0.85 : 0.3))
                }
                .buttonStyle(.plain)
                .disabled(!isParamModified(selectedParam))
                .help("Reset \(selectedParam.rawValue)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.black.opacity(0.68)))
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 0.8))
    }

    private func binding(for param: CameraAdjustParam) -> Binding<Double> {
        switch param {
        case .brightness: return $settings.mirrorBrightness
        case .glow: return $settings.mirrorGlow
        case .contrast: return $settings.mirrorContrast
        case .saturation: return $settings.mirrorSaturation
        case .warmth: return $settings.mirrorWarmth
        case .vignette: return $settings.mirrorVignette
        case .zoom: return $settings.mirrorZoom
        }
    }

    private func range(for param: CameraAdjustParam) -> ClosedRange<Double> {
        switch param {
        case .brightness: return -0.4...0.4
        case .glow: return 0.0...1.0
        case .contrast: return 0.6...1.5
        case .saturation: return 0.0...1.8
        case .warmth: return -1.0...1.0
        case .vignette: return 0.0...1.0
        case .zoom: return 1.0...2.5
        }
    }

    private func isParamModified(_ param: CameraAdjustParam) -> Bool {
        switch param {
        case .brightness: return abs(settings.mirrorBrightness) > 0.01
        case .glow: return settings.mirrorGlow > 0.01
        case .contrast: return abs(settings.mirrorContrast - 1.0) > 0.01
        case .saturation: return abs(settings.mirrorSaturation - 1.0) > 0.01
        case .warmth: return abs(settings.mirrorWarmth) > 0.01
        case .vignette: return settings.mirrorVignette > 0.01
        case .zoom: return settings.mirrorZoom > 1.01
        }
    }

    private func resetParam(_ param: CameraAdjustParam) {
        switch param {
        case .brightness: settings.mirrorBrightness = 0.0
        case .glow: settings.mirrorGlow = 0.0
        case .contrast: settings.mirrorContrast = 1.0
        case .saturation: settings.mirrorSaturation = 1.0
        case .warmth: settings.mirrorWarmth = 0.0
        case .vignette: settings.mirrorVignette = 0.0
        case .zoom: settings.mirrorZoom = 1.0
        }
    }

    private func formattedValue(for param: CameraAdjustParam) -> String {
        switch param {
        case .brightness:
            let v = Int(round(settings.mirrorBrightness * 250))
            return v > 0 ? "+\(v)" : "\(v)"
        case .glow:
            return "\(Int(round(settings.mirrorGlow * 100)))%"
        case .contrast:
            return "\(Int(round(settings.mirrorContrast * 100)))%"
        case .saturation:
            return "\(Int(round(settings.mirrorSaturation * 100)))%"
        case .warmth:
            let v = Int(round(settings.mirrorWarmth * 100))
            return v > 0 ? "+\(v)" : "\(v)"
        case .vignette:
            return "\(Int(round(settings.mirrorVignette * 100)))%"
        case .zoom:
            return String(format: "%.1fx", settings.mirrorZoom)
        }
    }

    private func toggle(isOn: Binding<Bool>, on: String, off: String, tint: Color, help: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: isOn.wrappedValue ? on : off)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? tint : .white.opacity(0.85))
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
