import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var weather: WeatherManager
    @EnvironmentObject private var updater: Updater
    @Namespace private var tabNamespace
    @State private var showMoreTabsPopover = false

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
        let overflowCount = max(0, tabs.count - 5)
        let displayedTabs: [NotchTab] = if overflowCount == 0 {
            tabs
        } else {
            Array(tabs.prefix(4)) + [tabs.firstIndex(of: vm.tab).flatMap { $0 >= 4 ? tabs[$0] : tabs[4] } ?? tabs[4]]
        }
        let showLabel = true
        let isCompact = overflowCount > 0 || displayedTabs.count > 4

        return HStack(spacing: isCompact ? 2 : 3) {
            ForEach(displayedTabs, id: \.self) { tab in
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

            if overflowCount > 0 {
                Button {
                    showMoreTabsPopover.toggle()
                } label: {
                    HStack(spacing: 2.5) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("+\(overflowCount)")
                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                    }
                    .foregroundStyle(showMoreTabsPopover ? .white : .secondary)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 3.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(showMoreTabsPopover ? 0.16 : 0.06))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("All tabs & quick launcher")
                .lockNotchWhilePresented($showMoreTabsPopover)
                .popover(isPresented: $showMoreTabsPopover, arrowEdge: .bottom) {
                    moreTabsGridPopover(visibleTabs: tabs)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .frame(maxWidth: maxWingWidth, alignment: .leading)
    }

    private func moreTabsGridPopover(visibleTabs: [NotchTab]) -> some View {
        let disabledTabs = NotchTab.allCases.filter { !settings.isTabEnabled($0) }
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                showMoreTabsPopover = false
                DispatchQueue.main.async {
                    AppDelegate.shared?.screenManager?.activeController?.panel.makeKeyAndOrderFront(nil)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                        vm.isCommandPaletteOpen = true
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Command Palette…")
                        .font(.system(size: 11.5, weight: .semibold))
                    Spacer()
                    Text("⌘K")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(Array(visibleTabs.enumerated()), id: \.element) { idx, tab in
                    let active = vm.tab == tab
                    Button {
                        showMoreTabsPopover = false
                        vm.selectTab(tab)
                    } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Image(systemName: tab.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(active ? Color.accentColor : .primary)
                                Spacer(minLength: 0)
                            }
                            .overlay(alignment: .topTrailing) {
                                if idx < 9 {
                                    Text("⌘\(idx + 1)")
                                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: active ? .bold : .medium))
                                .foregroundStyle(active ? Color.accentColor : .primary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(active ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(active ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !disabledTabs.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Hidden Tabs (click to enable)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 5) {
                        ForEach(disabledTabs, id: \.self) { tab in
                            Button {
                                settings.setTabEnabled(tab, true)
                                showMoreTabsPopover = false
                                vm.selectTab(tab)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 10))
                                    Text(tab.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 6)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.04)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    private var rightStatusView: some View {
        HStack(spacing: 3) {
            if settings.showMascot {
                NotchiHeaderAvatarButton()
                    .padding(.trailing, 1)
            }

            Button {
                AppDelegate.shared?.screenManager?.activeController?.panel.makeKeyAndOrderFront(nil)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                    vm.isCommandPaletteOpen.toggle()
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(vm.isCommandPaletteOpen ? .white : .secondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(vm.isCommandPaletteOpen ? 0.16 : 0)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Command Palette (⌘K)")

            // Weather and the watchlist share one slot and take turns, so the header never overflows.
            StatusRotator()
                .fixedSize()
                .padding(.trailing, 3)

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
                    Toggle("Calculator", isOn: $settings.calcTabEnabled)
                }
                Toggle("Desktop Lyrics", isOn: $settings.lyricsOverlayEnabled)
                    .disabled(!settings.lyricsEnabled)
                Toggle("Code Style Lyrics", isOn: $settings.lyricsCodeMode)
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
    @State private var showStatusPopover = false

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
                Button {
                    showStatusPopover.toggle()
                } label: {
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
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .id(item.id)
                .transition(.push(from: .bottom))
                .contextMenu {
                    if items.count > 1 {
                        Button("Next status item") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { index += 1 }
                        }
                    }
                    Button("Open Quick Look") { showStatusPopover = true }
                }
                .lockNotchWhilePresented($showStatusPopover)
                .popover(isPresented: $showStatusPopover, arrowEdge: .bottom) {
                    statusQuickLookPopover
                }
            }
        }
        .clipped()
        .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
            guard items.count > 1, !showStatusPopover else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { index += 1 }
        }
    }

    private var statusQuickLookPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            if settings.weatherEnabled, let snap = weather.snapshot {
                HStack(spacing: 10) {
                    Image(systemName: snap.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.weatherPlace.isEmpty ? "Weather" : settings.weatherPlace)
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("H \(Int(snap.high.rounded()))° · L \(Int(snap.low.rounded()))°")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(snap.temperature.rounded()))°")
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                    Button {
                        weather.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh weather")
                }
            }

            if settings.prayerEnabled && !prayers.today.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Prayer Schedule")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(prayers.today) { p in
                            let isNext = p.id == prayers.next?.id
                            HStack(spacing: 4) {
                                Image(systemName: p.kind.symbol)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.system(size: 10))
                                Text(prayers.name(p.kind))
                                    .font(.system(size: 10.5, weight: isNext ? .bold : .medium))
                                Spacer()
                                Text(p.date, format: .dateTime.hour().minute())
                                    .font(.system(size: 10.5, weight: isNext ? .bold : .regular).monospacedDigit())
                                    .foregroundStyle(isNext ? Color.accentColor : .secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3.5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(isNext ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04)))
                        }
                    }
                }
            }

            if !markets.watchlist.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Watchlist")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        Button("Open Markets →") {
                            settings.setTabEnabled(.markets, true)
                            showStatusPopover = false
                            vm.selectTab(.markets)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    }

                    ForEach(Array(markets.watchlist.prefix(4))) { quote in
                        HStack(spacing: 6) {
                            Text(quote.displaySymbol)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Spacer()
                            Text(quote.formattedPrice)
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(quote.formattedChange)
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundStyle(quote.change >= 0 ? .green : .red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill((quote.change >= 0 ? Color.green : Color.red).opacity(0.14)))
                        }
                    }
                }
            }

            if stats.isNetworkActive {
                Divider()
                HStack(spacing: 8) {
                    Text("Network")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(stats.formattedDown, systemImage: "arrow.down")
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.green)
                    Label(stats.formattedUp, systemImage: "arrow.up")
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.cyan)
                }
            }
        }
        .padding(12)
        .frame(width: 270)
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
