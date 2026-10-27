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
    /// When the exchange last traded at `price`; Yahoo's IDX prices run about 10 minutes behind.
    var priceTime: Date? = nil
    /// Updated every few seconds from Binance rather than Yahoo.
    var isLive = false

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

    static let presets = [
        "^JKSE", "BBCA.JK", "BBRI.JK", "TLKM.JK", "^GSPC", "^IXIC", "AAPL", "NVDA", "BTC-USD", "IDR=X",
    ]

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
        liveTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refreshLive() }
    }

    private var liveTimer: Timer?

    /// Binance pair for a Yahoo crypto symbol ("BTC-USD" → "BTCUSDT"); nil for everything else.
    static func binancePair(for symbol: String) -> String? {
        guard symbol.hasSuffix("-USD") else { return nil }
        let base = symbol.dropLast(4)
        guard !base.isEmpty, base.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return base.uppercased() + "USDT"
    }

    /// Live crypto prices from Binance's public market-data mirror (no key). Yahoo still supplies the
    /// previous close and sparkline; a symbol Binance doesn't list keeps its Yahoo price.
    func refreshLive() {
        guard settings.marketsEnabled || settings.showTickerInHeader else { return }
        let pairs = settings.marketTickers.compactMap { s in Self.binancePair(for: s).map { (s, $0) } }
        guard !pairs.isEmpty else { return }
        let list = "[" + pairs.map { "\"\($0.1)\"" }.joined(separator: ",") + "]"
        var components = URLComponents(string: "https://data-api.binance.vision/api/v3/ticker/price")!
        components.queryItems = [URLQueryItem(name: "symbols", value: list)]
        guard let url = components.url else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 5)) { [weak self] data, _, _ in
            let prices = data.map(Self.parseBinancePrices) ?? [:]
            guard !prices.isEmpty else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                for (symbol, pair) in pairs {
                    guard let price = prices[pair], var quote = self.quotes[symbol] else { continue }
                    quote = Quote(
                        symbol: quote.symbol, name: quote.name, price: price, previousClose: quote.previousClose,
                        currency: quote.currency, isMarketOpen: true, points: quote.points, priceTime: Date(),
                        isLive: true)
                    self.quotes[symbol] = quote
                }
            }
        }.resume()
    }

    /// A Yahoo refresh brings a new sparkline and previous close, but keeps a live price that's newer than its own.
    static func merge(yahoo: Quote, over current: Quote?) -> Quote {
        guard let current, current.isLive, let liveAt = current.priceTime, liveAt > (yahoo.priceTime ?? .distantPast)
        else { return yahoo }
        return Quote(
            symbol: yahoo.symbol, name: yahoo.name, price: current.price, previousClose: yahoo.previousClose,
            currency: yahoo.currency, isMarketOpen: yahoo.isMarketOpen, points: yahoo.points, priceTime: liveAt,
            isLive: true)
    }

    /// `[{"symbol":"BTCUSDT","price":"79782.01"}, …]` → pair: price.
    static func parseBinancePrices(_ data: Data) -> [String: Double] {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
        var out: [String: Double] = [:]
        for row in rows {
            if let pair = row["symbol"] as? String, let price = (row["price"] as? String).flatMap(Double.init) {
                out[pair] = price
            }
        }
        return out
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
                    guard let self else { return }
                    self.quotes[symbol] = Self.merge(yahoo: quote, over: self.quotes[symbol])
                    self.lastUpdated = Date()
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
        let encoded =
            symbol.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "=^"))) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=5m")
        else {
            return completion(nil)
        }
        URLSession.shared.dataTask(with: request(url)) { data, _, _ in
            guard let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let result = ((json["chart"] as? [String: Any])?["result"] as? [[String: Any]])?.first,
                let meta = result["meta"] as? [String: Any],
                let price = meta["regularMarketPrice"] as? Double
            else { return completion(nil) }

            let closes =
                ((((result["indicators"] as? [String: Any])?["quote"] as? [[String: Any]])?.first)?["close"] as? [Any])?
                .compactMap { $0 as? Double } ?? []
            let regular = (meta["currentTradingPeriod"] as? [String: Any])?["regular"] as? [String: Any]
            let now = Date().timeIntervalSince1970
            let start = regular?["start"] as? Double ?? 0
            let end = regular?["end"] as? Double ?? 0
            let isCrypto = (meta["instrumentType"] as? String) == "CRYPTOCURRENCY"

            completion(
                Quote(
                    symbol: symbol,
                    name: meta["shortName"] as? String ?? meta["longName"] as? String ?? symbol,
                    price: price,
                    previousClose: meta["chartPreviousClose"] as? Double ?? meta["previousClose"] as? Double ?? price,
                    currency: meta["currency"] as? String ?? "",
                    isMarketOpen: isCrypto || (now >= start && now <= end),
                    points: closes,
                    priceTime: (meta["regularMarketTime"] as? Double).map(Date.init(timeIntervalSince1970:))
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
            let quotes = json["quotes"] as? [[String: Any]]
        else { return [] }

        let allowed: Set<String> = ["EQUITY", "INDEX", "ETF", "CRYPTOCURRENCY", "CURRENCY", "MUTUALFUND", "FUTURE"]
        return quotes.compactMap { quote in
            guard let symbol = quote["symbol"] as? String,
                allowed.contains(quote["quoteType"] as? String ?? "")
            else { return nil }
            return TickerSearchResult(
                symbol: symbol,
                name: quote["shortname"] as? String ?? quote["longname"] as? String ?? symbol,
                exchange: quote["exchDisp"] as? String ?? quote["exchange"] as? String ?? ""
            )
        }
    }
}
