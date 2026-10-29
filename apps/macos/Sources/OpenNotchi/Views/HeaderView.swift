import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var weather: WeatherManager
    @EnvironmentObject private var updater: Updater
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            tabsBarView

            Spacer(minLength: 4)

            // Leave the camera housing area empty.
            Color.clear.frame(width: vm.hasPhysicalNotch ? vm.notchSize.width : 0)

            Spacer(minLength: 4)

            rightStatusView
        }
    }

    private var maxWingWidth: CGFloat {
        let notchWidth = vm.hasPhysicalNotch ? vm.notchSize.width : 160
        // Window width is 680 (or 720 for AI). Notch horizontal padding is ~32 on each side = 616pt usable.
        let usableWidth: CGFloat = (vm.tab == .ai ? 720 : NotchViewModel.openWidth) - 64
        let wing = (usableWidth - notchWidth) / 2
        return max(150, wing - 6)
    }

    private var tabsBarView: some View {
        let tabs = settings.visibleTabs
        let showLabel = tabs.count <= 5
        let isCompact = tabs.count > 5
        let spacing: CGFloat = tabs.count > 7 ? 1.5 : (tabs.count > 5 ? 2 : 3)

        return HStack(spacing: spacing) {
            ForEach(tabs, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: vm.tab == tab,
                    showLabel: showLabel,
                    isCompact: isCompact,
                    badge: tab == .tray ? tray.items.count : 0,
                    namespace: tabNamespace
                ) {
                    vm.selectTab(tab)
                }
                .id(tab)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .frame(maxWidth: maxWingWidth, alignment: .leading)
    }

    private var rightStatusView: some View {
        HStack(spacing: 3) {
            if settings.showMascot {
                NotchiHeaderAvatarButton()
                    .padding(.trailing, 2)
            }

            // Weather and the watchlist share one slot and take turns, so the header never overflows.
            StatusRotator()
                .fixedSize()
                .padding(.trailing, 4)

            if let update = updater.availableUpdate {
                Button {
                    updater.checkForUpdates()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .bold))
                        Text(update.version)
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Color.cyan.opacity(0.2)))
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.5), lineWidth: 0.8))
                    .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .help("OpenNotchi \(update.version) available. Click to update.")
                .padding(.trailing, 2)
            }

            if battery.hasBattery && settings.showHeaderBattery {
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
                    Toggle("AI (Quota & Agents)", isOn: $settings.aiEnabled)
                    Toggle("Smarthome", isOn: $settings.smarthomeEnabled)
                    Toggle("Prompter", isOn: $settings.prompterTabEnabled)
                    Toggle("Clipboard", isOn: $settings.clipboardEnabled)
                    Toggle("Timer", isOn: $settings.timerTabEnabled)
                    Toggle("Mirror", isOn: $settings.mirrorTabEnabled)
                    Toggle("Markets", isOn: $settings.marketsEnabled)
                    Toggle("Dev Tools", isOn: $settings.devToolsEnabled)
                    Toggle("Notes", isOn: $settings.notesTabEnabled)
                }
                Toggle("Desktop Lyrics", isOn: $settings.lyricsOverlayEnabled)
                    .disabled(!settings.lyricsEnabled)
                if settings.lyricsOverlayEnabled {
                    Toggle("Lock Desktop Lyrics", isOn: $settings.lyricsOverlayLocked)
                    Button("Reset Desktop Lyrics Position") { AppDelegate.shared?.resetLyricsOverlay() }
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .frame(maxWidth: maxWingWidth, alignment: .trailing)
    }
}

private struct TabButton: View {
    let tab: NotchTab
    let isSelected: Bool
    let showLabel: Bool
    let isCompact: Bool
    let badge: Int
    var namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 2.5 : 3.5) {
                Image(systemName: tab.icon)
                    .font(.system(size: isCompact ? 10.5 : 11.5, weight: isSelected ? .semibold : .medium))
                    .frame(width: isCompact ? 18 : 20, height: 18)
                if isSelected && showLabel {
                    Text(tab.rawValue)
                        .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
                        .fixedSize()
                }
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 0.5)
                        .background(Capsule().fill(.white.opacity(0.25)))
                }
            }
            .foregroundStyle(isSelected ? .white : isHovering ? .white.opacity(0.95) : .secondary)
            .padding(.horizontal, (isSelected && showLabel) ? (isCompact ? 6 : 8) : (isCompact ? 3.5 : 5))
            .padding(.vertical, 3.5)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.18))
                        .matchedGeometryEffect(id: "activeTabHighlight", in: namespace)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
        .onHover { isHovering = $0 }
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
