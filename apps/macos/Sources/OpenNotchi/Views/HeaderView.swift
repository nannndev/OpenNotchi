import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var weather: WeatherManager
    @EnvironmentObject private var updater: Updater

    var body: some View {
        HStack(spacing: 2) {
            tabsScrollView

            Spacer(minLength: 16)

            // Leave the camera housing area empty.
            Color.clear.frame(width: vm.hasPhysicalNotch ? vm.notchSize.width : 0)

            Spacer(minLength: 16)

            // Weather and the watchlist share one slot and take turns, so the header never overflows.
            StatusRotator()
                .fixedSize()
                .padding(.trailing, 8)

            if let update = updater.availableUpdate {
                Button {
                    updater.checkForUpdates()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                        Text(update.version)
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.cyan.opacity(0.2)))
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 0.8))
                    .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .help("OpenNotchi \(update.version) available. Click to update.")
                .padding(.trailing, 4)
            }

            if battery.hasBattery {
                BatteryView(level: battery.level, isCharging: battery.isCharging, isPluggedIn: battery.isPluggedIn)
                    .fixedSize()
            }

            Menu {
                if let update = updater.availableUpdate {
                    Button("Update to \(update.version)…") {
                        updater.checkForUpdates()
                    }
                    Divider()
                }
                Menu("Visible Tabs") {
                    Toggle("Clipboard", isOn: $settings.clipboardEnabled)
                    Toggle("Timer", isOn: $settings.timerTabEnabled)
                    Toggle("Mirror", isOn: $settings.mirrorTabEnabled)
                    Toggle("Markets", isOn: $settings.marketsEnabled)
                    Toggle("Dev Tools", isOn: $settings.devToolsEnabled)
                }
                Menu("Open Animation") {
                    ForEach(NotchAnimationStyle.allCases) { style in
                        Button {
                            settings.openAnimation = style
                        } label: {
                            HStack {
                                Label(style.displayName, systemImage: style.icon)
                                if settings.openAnimation == style {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Divider()
                Button("Settings…") { AppDelegate.shared?.showSettings() }
                Divider()
                Button("Quit OpenNotchi") { AppDelegate.shared?.quit() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var maxTabsWidth: CGFloat {
        let notchWidth = vm.hasPhysicalNotch ? vm.notchSize.width : 160
        // Window width is 680, header padding is 32 on each side = 616pt header width.
        // Center is at 308pt. Notch spans (308 - notchWidth/2) to (308 + notchWidth/2).
        let wing = (616 - notchWidth) / 2
        return max(160, wing - 14)
    }

    private var tabsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(settings.visibleTabs, id: \.self) { tab in
                        TabButton(tab: tab, isSelected: vm.tab == tab, badge: tab == .tray ? tray.items.count : 0) {
                            vm.tab = tab
                        }
                        .id(tab)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
            }
            .background(HorizontalWheelScrollHelper())
            .frame(maxWidth: maxTabsWidth, alignment: .leading)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.90),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onChange(of: vm.tab) { _, newTab in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo(newTab, anchor: .center)
                }
            }
        }
    }
}

private struct TabButton: View {
    let tab: NotchTab
    let isSelected: Bool
    let badge: Int
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .medium))
                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize()
                }
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.white.opacity(0.2)))
                }
            }
            .foregroundStyle(isSelected ? .white : isHovering ? .white.opacity(0.9) : .secondary)
            .padding(.horizontal, isSelected ? 8 : 6)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? .white.opacity(0.18) : isHovering ? .white.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

/// Helper that translates vertical mouse-wheel events into horizontal scrolling for the enclosing NSScrollView.
private struct HorizontalWheelScrollHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> WheelCatcher {
        WheelCatcher()
    }
    func updateNSView(_ nsView: WheelCatcher, context: Context) {}

    class WheelCatcher: NSView {
        override func scrollWheel(with event: NSEvent) {
            if event.scrollingDeltaX == 0 && event.scrollingDeltaY != 0 {
                if let scrollView = enclosingScrollView {
                    let clipView = scrollView.contentView
                    var newOrigin = clipView.bounds.origin
                    let delta = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
                    newOrigin.x -= delta * 1.6
                    let maxScroll = max(0, (scrollView.documentView?.frame.width ?? 0) - clipView.bounds.width)
                    newOrigin.x = min(max(0, newOrigin.x), maxScroll)
                    clipView.scroll(to: newOrigin)
                    scrollView.reflectScrolledClipView(clipView)
                    return
                }
            }
            super.scrollWheel(with: event)
        }
    }
}

/// One header slot that cycles through the weather and the watchlist tickers.
private struct StatusRotator: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var weather: WeatherManager
    @EnvironmentObject private var markets: MarketManager
    @EnvironmentObject private var prayers: PrayerTimesManager
    @EnvironmentObject private var stats: SystemStatsManager
    @EnvironmentObject private var vm: NotchViewModel
    @State private var index = 0

    private enum Item: Equatable {
        case prayer(PrayerTime)
        case weather(WeatherSnapshot)
        case quote(Quote)
        case network(down: String, up: String)

        var id: String {
            switch self {
            case .prayer: return "prayer"
            case .weather: return "weather"
            case .quote(let quote): return quote.symbol
            case .network: return "network"
            }
        }
    }

    private var items: [Item] {
        var items: [Item] = []
        if let next = prayers.next { items.append(.prayer(next)) }
        if settings.weatherEnabled, let snapshot = weather.snapshot { items.append(.weather(snapshot)) }
        // Live network traffic if active
        if settings.showStatsInHeader && stats.isNetworkActive {
            items.append(.network(down: stats.formattedDown, up: stats.formattedUp))
        }
        // The Markets tab already shows every ticker.
        if settings.showTickerInHeader && vm.tab != .markets {
            items += markets.watchlist.map(Item.quote)
        }
        return items
    }

    var body: some View {
        let items = self.items
        Group {
            if !items.isEmpty {
                let item = items[index % items.count]
                Group {
                    switch item {
                    case .prayer(let prayer):
                        HStack(spacing: 5) {
                            Image(systemName: prayer.kind.symbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 12))
                            Text(prayers.name(prayer.kind)).font(.system(size: 12, weight: .bold, design: .rounded))
                            Text(prayer.date, format: .dateTime.hour().minute())
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .help(prayers.today.map { "\(prayers.name($0.kind))  \($0.date.formatted(date: .omitted, time: .shortened))" }.joined(separator: "\n"))
                    case .weather(let snapshot):
                        WeatherBadge(snapshot: snapshot, place: settings.weatherPlace)
                    case .quote(let quote):
                        HStack(spacing: 4) {
                            Text(quote.displaySymbol).font(.system(size: 12, weight: .bold, design: .rounded))
                            Text(quote.formattedChange)
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(quote.change >= 0 ? .green : .red)
                        }
                        .help("\(quote.name): \(quote.formattedPrice) \(quote.currency)")
                    case .network(let down, let up):
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.green)
                            Text(down)
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.cyan)
                            Text(up)
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        }
                        .help("Live network: Download \(down) · Upload \(up)")
                    }
                }
                .id(item.id)
                .transition(.push(from: .bottom))
            }
        }
        .clipped()
        .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
            guard items.count > 1 else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { index += 1 }
        }
    }
}

private struct WeatherBadge: View {
    let snapshot: WeatherSnapshot
    let place: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: snapshot.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 13))
            Text("\(Int(snapshot.temperature.rounded()))°")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
        }
        .help("\(place) · H \(Int(snapshot.high.rounded()))° L \(Int(snapshot.low.rounded()))°")
    }
}

struct BatteryView: View {
    let level: Int
    let isCharging: Bool
    let isPluggedIn: Bool

    private var color: Color {
        if isCharging || isPluggedIn { return .green }
        if level <= 20 { return .red }
        return .white
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(level)%")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.4), lineWidth: 1)
                    .frame(width: 26, height: 13)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(color)
                    .frame(width: max(2, 22 * CGFloat(level) / 100), height: 9)
                    .padding(.leading, 2)
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 26)
                }
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.4))
                .frame(width: 2, height: 5)
                .padding(.leading, -5)
        }
    }
}
