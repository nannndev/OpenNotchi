import SwiftUI

/// Watchlist grid: price, today's change and an intraday sparkline per ticker.
struct MarketsView: View {
    @EnvironmentObject private var markets: MarketManager
    @EnvironmentObject private var settings: AppSettings

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 6) {
            if settings.marketTickers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 22, weight: .light))
                    Text("Add tickers in Settings → Features → Markets").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(settings.marketTickers, id: \.self) { symbol in
                            if let quote = markets.quotes[symbol] {
                                QuoteCard(quote: quote)
                            } else {
                                RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.05)).frame(height: 62)
                                    .overlay(Text(Quote.displaySymbol(for: symbol)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary))
                            }
                        }
                    }
                }
                HStack {
                    Text("Delayed quotes · Yahoo Finance")
                    Spacer()
                    if let updated = markets.lastUpdated {
                        Text("Updated \(updated, format: .dateTime.hour().minute())")
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            }
        }
        .onAppear { markets.refresh() }
    }
}

private struct QuoteCard: View {
    let quote: Quote

    private var color: Color { quote.change >= 0 ? .green : .red }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Circle().fill(quote.isMarketOpen ? Color.green : .white.opacity(0.25)).frame(width: 5, height: 5)
                    Text(quote.displaySymbol)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                Text(quote.formattedPrice)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(quote.formattedChange)
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(color)
            }
            Spacer(minLength: 0)
            Sparkline(points: quote.points, baseline: quote.previousClose, color: color)
                .frame(width: 54, height: 34)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 62)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
        .help("\(quote.name) · \(quote.currency)\(quote.isMarketOpen ? "" : " · market closed")")
    }
}

/// Intraday line with a dashed line at the previous close.
struct Sparkline: View {
    let points: [Double]
    let baseline: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let low = min(points.min() ?? baseline, baseline)
            let high = max(points.max() ?? baseline, baseline)
            let range = max(high - low, .ulpOfOne)
            let y = { (value: Double) in geo.size.height * (1 - (value - low) / range) }

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y(baseline)))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y(baseline)))
                }
                .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))

                if points.count > 1 {
                    Path { path in
                        for (i, value) in points.enumerated() {
                            let point = CGPoint(x: geo.size.width * CGFloat(i) / CGFloat(points.count - 1), y: y(value))
                            i == 0 ? path.move(to: point) : path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}
