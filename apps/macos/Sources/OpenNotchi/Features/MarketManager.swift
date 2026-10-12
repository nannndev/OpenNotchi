import Combine
import Foundation

struct Quote: Identifiable, Equatable {
    let symbol: String
    let name: String
    let price: Double
    let previousClose: Double
    let currency: String
    let isMarketOpen: Bool
    /// Intraday closes for the sparkline.
    let points: [Double]

    var id: String { symbol }
    var change: Double { price - previousClose }
    var changePercent: Double { previousClose == 0 ? 0 : change / previousClose * 100 }

    /// Short label: "BBCA" for BBCA.JK, "IHSG" for ^JKSE, "USD/IDR" for IDR=X.
    var displaySymbol: String { Quote.displaySymbol(for: symbol) }

    static func displaySymbol(for symbol: String) -> String {
        switch symbol {
        case "^JKSE": return "IHSG"
        case "^GSPC": return "S&P 500"
        case "^IXIC": return "NASDAQ"
        case "^DJI": return "DOW"
        case "^N225": return "NIKKEI"
        case "^HSI": return "HANG SENG"
        default: break
        }
        if symbol.hasSuffix("=X") { return "USD/" + symbol.dropLast(2) }
        if symbol.hasSuffix("-USD") { return String(symbol.dropLast(4)) }
        if let dot = symbol.firstIndex(of: ".") { return String(symbol[..<dot]) }
        return symbol
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let digits = currency == "IDR" || price >= 10_000 ? 0 : 2
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: price)) ?? String(price)
    }

    var formattedChange: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return (formatter.string(from: NSNumber(value: changePercent)) ?? "0") + "%"
    }
}

struct TickerSearchResult: Identifiable, Hashable {
    let symbol: String
    let name: String
    let exchange: String
    var id: String { symbol }
}

/// Delayed quotes from Yahoo Finance (free, no API key) for the user's watchlist.
/// Display only, not investment advice.
final class MarketManager: ObservableObject {
    @Published private(set) var quotes: [String: Quote] = [:]
    @Published private(set) var lastUpdated: Date?

    static let presets = ["^JKSE", "BBCA.JK", "BBRI.JK", "TLKM.JK", "^GSPC", "^IXIC", "AAPL", "NVDA", "BTC-USD", "IDR=X"]

    private let settings: AppSettings
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings) {
        self.settings = settings
        settings.$marketTickers
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        timer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in self?.refresh() }
    }

    /// Quotes in watchlist order (tickers that failed to load are skipped).
    var watchlist: [Quote] {
        settings.marketTickers.compactMap { quotes[$0] }
    }

    func refresh() {
        guard settings.marketsEnabled || settings.showTickerInHeader else { return }
        for symbol in settings.marketTickers {
            Self.fetch(symbol) { [weak self] quote in
                guard let quote else { return }
                DispatchQueue.main.async {
                    self?.quotes[symbol] = quote
                    self?.lastUpdated = Date()
                }
            }
        }
    }

    // MARK: - Yahoo Finance

    private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        // Yahoo rejects requests without a browser-like user agent.
        request.setValue("Mozilla/5.0 (Macintosh) OpenNotchi", forHTTPHeaderField: "User-Agent")
        return request
    }

    private static func fetch(_ symbol: String, completion: @escaping (Quote?) -> Void) {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "=^"))) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=5m") else {
            return completion(nil)
        }
        URLSession.shared.dataTask(with: request(url)) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = ((json["chart"] as? [String: Any])?["result"] as? [[String: Any]])?.first,
                  let meta = result["meta"] as? [String: Any],
                  let price = meta["regularMarketPrice"] as? Double else { return completion(nil) }

            let closes = ((((result["indicators"] as? [String: Any])?["quote"] as? [[String: Any]])?.first)?["close"] as? [Any])?
                .compactMap { $0 as? Double } ?? []
            let regular = (meta["currentTradingPeriod"] as? [String: Any])?["regular"] as? [String: Any]
            let now = Date().timeIntervalSince1970
            let start = regular?["start"] as? Double ?? 0
            let end = regular?["end"] as? Double ?? 0
            let isCrypto = (meta["instrumentType"] as? String) == "CRYPTOCURRENCY"

            completion(Quote(
                symbol: symbol,
                name: meta["shortName"] as? String ?? meta["longName"] as? String ?? symbol,
                price: price,
                previousClose: meta["chartPreviousClose"] as? Double ?? meta["previousClose"] as? Double ?? price,
                currency: meta["currency"] as? String ?? "",
                isMarketOpen: isCrypto || (now >= start && now <= end),
                points: closes
            ))
        }.resume()
    }

    static func search(_ query: String) async -> [TickerSearchResult] {
        var components = URLComponents(string: "https://query2.finance.yahoo.com/v1/finance/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "quotesCount", value: "8"),
            URLQueryItem(name: "newsCount", value: "0"),
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(for: request(url)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let quotes = json["quotes"] as? [[String: Any]] else { return [] }

        let allowed: Set<String> = ["EQUITY", "INDEX", "ETF", "CRYPTOCURRENCY", "CURRENCY", "MUTUALFUND", "FUTURE"]
        return quotes.compactMap { quote in
            guard let symbol = quote["symbol"] as? String,
                  allowed.contains(quote["quoteType"] as? String ?? "") else { return nil }
            return TickerSearchResult(
                symbol: symbol,
                name: quote["shortname"] as? String ?? quote["longname"] as? String ?? symbol,
                exchange: quote["exchDisp"] as? String ?? quote["exchange"] as? String ?? ""
            )
        }
    }
}
