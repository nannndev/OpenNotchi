import SwiftUI

/// Watchlist editor: search Yahoo Finance, add presets, reorder and remove.
struct MarketSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var query = ""
    @State private var results: [TickerSearchResult] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Toggle("Markets tab", isOn: $settings.marketsEnabled)
        Toggle("Rotate tickers in the notch header", isOn: $settings.showTickerInHeader)

        ForEach(Array(settings.marketTickers.enumerated()), id: \.element) { index, symbol in
            HStack {
                Text(Quote.displaySymbol(for: symbol)).fontWeight(.semibold)
                Text(symbol).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(index == 0)
                Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(index == settings.marketTickers.count - 1)
                Button { settings.marketTickers.remove(at: index) } label: { Image(systemName: "minus.circle.fill") }
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }

        TextField("Search ticker or company (e.g. BBCA, Tesla, Bitcoin)", text: $query)
            .onChange(of: query) { _, value in search(value) }
        ForEach(results) { result in
            Button { add(result.symbol) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(result.symbol).fontWeight(.semibold)
                        Text(result.name).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(result.exchange).font(.caption).foregroundStyle(.secondary)
                    Image(systemName: settings.marketTickers.contains(result.symbol) ? "checkmark" : "plus.circle")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        LabeledContent("Quick add") {
            HStack(spacing: 6) {
                ForEach(MarketManager.presets.filter { !settings.marketTickers.contains($0) }.prefix(5), id: \.self) { symbol in
                    Button(Quote.displaySymbol(for: symbol)) { add(symbol) }
                        .controlSize(.small)
                }
            }
        }

        Text("Indonesian stocks end in .JK (BBCA.JK). Quotes are delayed and for information only, not investment advice.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func add(_ symbol: String) {
        guard !settings.marketTickers.contains(symbol) else { return }
        settings.marketTickers.append(symbol)
        query = ""
        results = []
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard settings.marketTickers.indices.contains(target) else { return }
        settings.marketTickers.swapAt(index, target)
    }

    private func search(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let found = await MarketManager.search(trimmed)
            if !Task.isCancelled { results = found }
        }
    }
}
