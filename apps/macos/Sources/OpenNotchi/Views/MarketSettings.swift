import SwiftUI

/// Watchlist editor: search Yahoo Finance, add presets, reorder and remove.
struct MarketSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var query = ""
    @State private var results: [TickerSearchResult] = []
    @State private var searchTask: Task<Void, Never>?

    private let chipColumns = [GridItem(.adaptive(minimum: 125), spacing: 8)]

    var body: some View {
        Toggle("Enable Markets tab in notch", isOn: $settings.marketsEnabled)
        Toggle("Rotate tickers in the notch header", isOn: $settings.showTickerInHeader)

        if !settings.marketTickers.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Active Watchlist (\(settings.marketTickers.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: chipColumns, spacing: 8) {
                    ForEach(Array(settings.marketTickers.enumerated()), id: \.element) { index, symbol in
                        HStack(spacing: 5) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(Quote.displaySymbol(for: symbol))
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                Text(symbol)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 2)
                            HStack(spacing: 2) {
                                Button { move(index, by: -1) } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .disabled(index == 0)
                                .help("Move earlier")

                                Button { move(index, by: 1) } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .disabled(index == settings.marketTickers.count - 1)
                                .help("Move later")

                                Button { settings.marketTickers.remove(at: index) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red.opacity(0.85))
                                }
                                .help("Remove \(symbol)")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.vertical, 2)
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
