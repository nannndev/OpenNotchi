import SwiftUI

/// A reminder below the notch: icon and badge beside the camera, title and an action underneath.
struct BannerView: View {
    static let contentHeight: CGFloat = 56

    @EnvironmentObject private var vm: NotchViewModel
    let banner: Banner
    let height: CGFloat
    @State private var appeared = false
    @State private var shownAt = Date.now

    /// Attention banners pulse until dismissed; the rest settle after one bounce.
    private var pulses: Bool { banner.kind == .attention }

    var body: some View {
        VStack(spacing: 0) {
            // Beside the notch: a tinted badge on the right; the icon moves down into the card.
            HStack {
                Circle()
                    .fill(banner.tint)
                    .frame(width: 6, height: 6)
                    .shadow(color: banner.tint, radius: 4)
                    .opacity(pulses ? (appeared ? 1 : 0.3) : 1)
                    .animation(pulses ? .easeInOut(duration: 0.7).repeatForever() : .default, value: appeared)
                    .frame(width: height - 6)
                Spacer()
                Text(banner.badge)
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(banner.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(banner.tint.opacity(0.18)))
            }
            .frame(height: height)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [banner.tint.opacity(0.55), banner.tint.opacity(0.12)], center: .center, startRadius: 2, endRadius: 22))
                    Circle().stroke(banner.tint.opacity(0.5), lineWidth: 1)
                    Image(systemName: banner.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: appeared)
                }
                .frame(width: 36, height: 36)
                .scaleEffect(appeared ? 1 : 0.4)
                .shadow(color: banner.tint.opacity(0.6), radius: appeared ? 8 : 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(banner.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    if let subtitle = banner.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .offset(x: appeared ? 0 : -8)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 4)
                if let title = banner.actionTitle {
                    Button {
                        if banner.actionType == .triggerUpdate {
                            AppDelegate.shared?.updater.checkForUpdates()
                        } else if let url = banner.actionURL {
                            NSWorkspace.shared.open(url)
                        }
                        vm.dismissPeek()
                    } label: {
                        Label(title, systemImage: banner.actionType == .triggerUpdate ? "arrow.triangle.2.circlepath" : banner.actionURL?.isFileURL == true ? "arrow.up.forward.app" : "video.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(banner.tint.gradient))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    vm.dismissPeek()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            .padding(.leading, 6)
            .frame(height: Self.contentHeight - 8)

            // Time left before the banner closes itself.
            TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                let left = max(0, 1 - context.date.timeIntervalSince(shownAt) / banner.duration)
                GeometryReader { geo in
                    Capsule()
                        .fill(banner.tint.opacity(0.7))
                        .frame(width: geo.size.width * left, height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 24)
        }
        // A soft glow in the banner's color from the bottom edge.
        .background(alignment: .bottom) {
            Ellipse()
                .fill(banner.tint.opacity(appeared ? 0.22 : 0))
                .frame(height: 40)
                .blur(radius: 18)
                .offset(y: 14)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            vm.dismissPeek()
            vm.open()
        }
        .onAppear {
            shownAt = .now
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { appeared = true }
        }
    }
}

/// An AirPods / Bluetooth connection drop-down card in the Dynamic Island.
struct DeviceBannerView: View {
    static let contentHeight: CGFloat = 46

    let name: String
    let symbol: String
    let battery: Int?
    let info: DeviceBatteryInfo?
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Upper row beside the physical notch
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: height * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.35), radius: 4)
                        .frame(width: height - 6)
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.95, blue: 0.4))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.green.opacity(0.8), radius: 4)
                    Text("Connected")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.2, green: 0.95, blue: 0.4))
                }
            }
            .frame(height: height)

            // Lower card underneath the physical notch
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Battery indicators
                if let info, info.isAirPods {
                    HStack(spacing: 7) {
                        if let l = info.left {
                            batteryPill(label: "L", level: l, icon: "airpod.left")
                        }
                        if let r = info.right {
                            batteryPill(label: "R", level: r, icon: "airpod.right")
                        }
                        if let c = info.caseBattery {
                            batteryPill(label: "Case", level: c, icon: "airpodspro.chargingcase.wireless.fill")
                        }
                    }
                } else if let b = battery ?? info?.primaryBattery {
                    HStack(spacing: 5) {
                        Image(systemName: batteryIcon(for: b))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(b <= 20 ? .red : .green)
                        Text("\(b)%")
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(b <= 20 ? .red : .white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.12)))
                }
            }
            .padding(.horizontal, 4)
            .frame(height: Self.contentHeight)
        }
    }

    private var subtitleText: String {
        if symbol.contains("airpod") { return "Spatial Audio Active" }
        if symbol.contains("keyboard") { return "Bluetooth Keyboard" }
        if symbol.contains("mouse") { return "Bluetooth Mouse" }
        if symbol.contains("trackpad") { return "Bluetooth Trackpad" }
        return "Bluetooth Connected"
    }

    private func batteryPill(label: String, level: Int, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text("\(level)%")
                .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(level <= 20 ? .red : .white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(Capsule().fill(.white.opacity(0.12)))
    }

    private func batteryIcon(for level: Int) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }
}
