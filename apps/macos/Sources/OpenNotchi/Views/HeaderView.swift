import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var weather: WeatherManager

    var body: some View {
        HStack(spacing: 2) {
            ForEach(settings.visibleTabs, id: \.self) { tab in
                TabButton(tab: tab, isSelected: vm.tab == tab, badge: tab == .tray ? tray.items.count : 0) {
                    vm.tab = tab
                }
            }

            Spacer()

            // Leave the camera housing area empty.
            Color.clear.frame(width: vm.hasPhysicalNotch ? vm.notchSize.width : 0)

            Spacer()

            // Weather and the watchlist share one slot and take turns, so the header never overflows.
            StatusRotator()
                .fixedSize()
                .padding(.trailing, 8)

            if battery.hasBattery {
                BatteryView(level: battery.level, isCharging: battery.isCharging, isPluggedIn: battery.isPluggedIn)
                    .fixedSize()
            }

            Menu {
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
}

private struct TabButton: View {
    let tab: NotchTab
    let isSelected: Bool
    let badge: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                if isSelected {
                    Text(tab.rawValue)
                        .fixedSize()
                }
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .background(Capsule().fill(.white.opacity(0.2)))
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, isSelected ? 9 : 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(.white.opacity(isSelected ? 0.15 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

/// One header slot that cycles through the weather and the watchlist tickers.
private struct StatusRotator: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var weather: WeatherManager
    @EnvironmentObject private var markets: MarketManager
    @EnvironmentObject private var prayers: PrayerTimesManager
    @EnvironmentObject private var vm: NotchViewModel
    @State private var index = 0

    private enum Item: Equatable {
        case prayer(PrayerTime)
        case weather(WeatherSnapshot)
        case quote(Quote)

        var id: String {
            switch self {
            case .prayer: return "prayer"
            case .weather: return "weather"
            case .quote(let quote): return quote.symbol
            }
        }
    }

    private var items: [Item] {
        var items: [Item] = []
        if let next = prayers.next { items.append(.prayer(next)) }
        if settings.weatherEnabled, let snapshot = weather.snapshot { items.append(.weather(snapshot)) }
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
