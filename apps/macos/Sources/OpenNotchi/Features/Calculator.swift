import Foundation

/// Expression calculator: + - * / ^ %, parentheses, sqrt/sin/cos/tan/log/ln/abs, pi and e,
/// plus everyday phrases ("15% dari 200rb", "200rb + ppn 11%"), unit and date questions,
/// and "100 usd to idr" currency conversion (rates looked up by the caller).
enum Calculator {
    struct Conversion: Equatable {
        let amount: Double
        let from: String
        let to: String
    }

    /// What the answer box shows; `value` is what Enter carries forward (nil for a date).
    struct Answer: Equatable {
        let text: String
        let value: Double?
    }

    /// "100*2 usd to idr", "50 eur ke idr", "1jt idr in usd" → amount + ISO codes; nil if not a conversion.
    static func parseConversion(_ input: String) -> Conversion? {
        guard let (amount, from, to) = splitConversion(input),
            unitFactor(from) == nil, unitFactor(to) == nil, temperature(from) == nil, temperature(to) == nil,
            isCurrency(from), isCurrency(to)
        else { return nil }
        return Conversion(amount: amount, from: from.uppercased(), to: to.uppercased())
    }

    /// "<amount> <from> to|in|ke|= <to>"; also takes the unit glued on ("5km to mi").
    private static func splitConversion(_ input: String) -> (Double, String, String)? {
        var words = input.lowercased().split(separator: " ").map(String.init)
        guard let sep = words.lastIndex(where: { ["to", "in", "ke", "="].contains($0) }),
            sep >= 1, sep == words.count - 2
        else { return nil }
        let to = words[sep + 1]
        words = Array(words[..<sep])
        var from = words.removeLast()
        if let first = from.first, first.isNumber || first == "." || first == ")" {
            let unit = String(from.reversed().prefix { $0.isLetter || $0 == "°" }.reversed())
            guard !unit.isEmpty else { return nil }
            words.append(String(from.dropLast(unit.count)))
            from = unit
        }
        guard let amount = evaluate(words.joined(separator: " ")) else { return nil }
        return (amount, from, to)
    }

    static func isCurrency(_ code: String) -> Bool { code.count == 3 && code.allSatisfy(\.isLetter) }

    /// Yahoo forex symbol for one `from` in `to`.
    static func rateSymbol(from: String, to: String) -> String { "\(from)\(to)=X" }

    static func evaluate(_ input: String) -> Double? {
        var parser = Parser(Array(rewrite(input.lowercased().replacingOccurrences(of: ",", with: "."))))
        guard let value = parser.expression(), parser.atEnd, value.isFinite else { return nil }
        return value
    }

    private struct Parser {
        var chars: [Character]
        var i = 0
        init(_ chars: [Character]) { self.chars = chars.filter { $0 != " " && $0 != "_" } }

        var atEnd: Bool { i == chars.count }
        private var peek: Character? { i < chars.count ? chars[i] : nil }

        private mutating func eat(_ set: String) -> Character? {
            guard let c = peek, set.contains(c) else { return nil }
            i += 1
            return c
        }

        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while let op = eat("+-") {
                guard let rhs = term() else { return nil }
                // Phone-calculator percent: 200 + 10% = 220, 200 - 10% = 180.
                let isPercent = chars[i - 1] == "%"
                value =
                    isPercent ? value * (op == "+" ? 1 + rhs : 1 - rhs) : op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while let op = eat("*/x×÷") {
                guard let rhs = power() else { return nil }
                value = op == "/" || op == "÷" ? value / rhs : value * rhs
            }
            return value
        }

        private mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            guard eat("^") != nil else { return base }
            guard let exponent = power() else { return nil } // right-associative: 2^3^2 = 2^9
            return pow(base, exponent)
        }

        private mutating func unary() -> Double? {
            if eat("-") != nil { return unary().map { -$0 } }
            if eat("+") != nil { return unary() }
            guard var value = primary() else { return nil }
            while eat("%") != nil { value /= 100 }
            return value
        }

        private mutating func primary() -> Double? {
            if eat("(") != nil {
                let value = expression()
                return eat(")") != nil ? value : nil
            }
            if let c = peek, c.isNumber || c == "." {
                let start = i
                while let c = peek, c.isNumber || c == "." { i += 1 }
                var digits = String(chars[start..<i])
                if digits.filter({ $0 == "." }).count > 1 { digits.removeAll { $0 == "." } } // 1.500.000
                guard var value = Double(digits) else { return nil }
                // Indonesian shorthand: 5rb, 2jt, 1m (miliar).
                for (suffix, mult) in [("rb", 1e3), ("k", 1e3), ("jt", 1e6), ("m", 1e9)] where lookahead(suffix) {
                    i += suffix.count
                    value *= mult
                    break
                }
                return value
            }
            let start = i
            while let c = peek, c.isLetter { i += 1 }
            let name = String(chars[start..<i])
            switch name {
            case "pi", "π": return .pi
            case "e": return M_E
            case "": return nil
            default: break
            }
            guard eat("(") != nil, let arg = expression(), eat(")") != nil else { return nil }
            switch name {
            case "sqrt": return arg.squareRoot()
            case "abs": return abs(arg)
            case "sin": return sin(arg * .pi / 180)
            case "cos": return cos(arg * .pi / 180)
            case "tan": return tan(arg * .pi / 180)
            case "log": return log10(arg)
            case "ln": return log(arg)
            default: return nil
            }
        }

        private func lookahead(_ s: String) -> Bool {
            let s = Array(s)
            guard i + s.count <= chars.count, Array(chars[i..<i + s.count]) == s else { return false }
            // "2m" is a multiplier, but not the start of a word like "2mod".
            return i + s.count == chars.count || !chars[i + s.count].isLetter
        }
    }

    // MARK: - Everyday phrases

    /// Turns phrases into plain math the parser understands; anything else passes through.
    private static func rewrite(_ s: String) -> String {
        let s = s.trimmingCharacters(in: .whitespaces)
        var out = s
        if let m = s.wholeMatch(of: #/(?:diskon|discount)\s+(.+?)%\s+(?:dari|of)\s+(.+)/#) {
            out = "(\(m.2))-(\(m.1))%"
        } else if let m = s.wholeMatch(of: #/(.+?)%\s+off\s+(.+)/#) {
            out = "(\(m.2))-(\(m.1))%"
        } else if let m = s.wholeMatch(of: #/(.+?)\s+(?:diskon|discount|off)\s+(.+?)%/#) {
            out = "(\(m.1))-(\(m.2))%"
        } else if let m = s.wholeMatch(of: #/(?:naik|tambah|increase)\s+(.+?)%\s+(?:dari|of|from)\s+(.+)/#) {
            out = "(\(m.2))+(\(m.1))%"
        } else if let m = s.wholeMatch(of: #/(?:turun|kurang|decrease)\s+(.+?)%\s+(?:dari|of|from)\s+(.+)/#) {
            out = "(\(m.2))-(\(m.1))%"
        } else if let m = s.wholeMatch(of: #/(.+?)%\s+(?:dari|of)\s+(.+)/#) {
            out = "(\(m.1))%*(\(m.2))"
        }
        // "200rb + ppn 11%" → "200rb + 11%"
        return out.replacing(#/\b(?:ppn|pph|pajak|tax|tip|service|servis)\b/#, with: "")
    }

    /// Unit, date and "what percent" questions, or nil to fall back to currency / plain math.
    static func smart(_ input: String, now: Date = Date()) -> Answer? {
        let s = input.lowercased().replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if let answer = dateAnswer(s, now: now) ?? unitAnswer(s) { return answer }
        if let m = s.wholeMatch(of: #/(.+?)\s+(?:dari|of)\s+(.+?)\s+(?:berapa\s+persen|dalam\s+persen|in\s+%|as\s+%)\??/#)
            ?? s.wholeMatch(of: #/(.+?)\s+is\s+what\s+(?:%|percent)\s+of\s+(.+?)\??/#),
            let part = evaluate(String(m.1)), let whole = evaluate(String(m.2)), whole != 0
        {
            let pct = part / whole * 100
            return Answer(text: format(pct, maxFraction: 2) + "%", value: pct)
        }
        return nil
    }

    // MARK: - Units

    private static let units: [String: (kind: String, factor: Double)] = {
        var u: [String: (String, Double)] = [:]
        func add(_ kind: String, _ factor: Double, _ names: String...) { for n in names { u[n] = (kind, factor) } }
        add("length", 1, "m", "meter", "meters", "metre")
        add("length", 1000, "km", "kilometer", "kilometers")
        add("length", 0.01, "cm")
        add("length", 0.001, "mm")
        add("length", 1609.344, "mi", "mile", "miles")
        add("length", 0.3048, "ft", "feet", "foot", "kaki")
        add("length", 0.0254, "inch", "inches", "inci")
        add("length", 0.9144, "yd", "yard", "yards")
        add("mass", 1, "kg", "kilo", "kilogram")
        add("mass", 0.001, "g", "gr", "gram", "grams")
        add("mass", 1e-6, "mg")
        add("mass", 0.1, "ons") // Indonesian ons = 100 g
        add("mass", 100, "kuintal")
        add("mass", 1000, "ton", "tons", "tonnes")
        add("mass", 0.45359237, "lb", "lbs", "pound", "pounds")
        add("mass", 0.028349523125, "oz", "ounce", "ounces")
        // Binary sizes (1 GB = 1024 MB), what most people expect from a calculator.
        add("data", 1, "b", "byte", "bytes")
        add("data", 1024, "kb")
        add("data", 1_048_576, "mb")
        add("data", 1_073_741_824, "gb")
        add("data", 1_099_511_627_776, "tb")
        add("time", 1, "s", "sec", "secs", "second", "seconds", "detik")
        add("time", 60, "min", "mins", "minute", "minutes", "menit")
        add("time", 3600, "h", "hr", "hrs", "hour", "hours", "jam")
        add("time", 86400, "day", "days", "hari")
        add("time", 604_800, "week", "weeks", "minggu")
        add("time", 2_592_000, "month", "months", "bulan") // 30 days
        add("time", 31_536_000, "year", "years", "tahun") // 365 days
        add("volume", 1, "l", "liter", "litre", "liters")
        add("volume", 0.001, "ml")
        add("volume", 3.785411784, "gal", "gallon", "gallons")
        add("speed", 1, "kmh", "kph", "km/h")
        add("speed", 1.609344, "mph")
        add("speed", 3.6, "m/s", "mps")
        add("area", 1, "m2", "m²")
        add("area", 10_000, "ha", "hektar", "hectare")
        add("area", 1_000_000, "km2", "km²")
        add("area", 0.09290304, "ft2", "ft²")
        return u
    }()

    private static func unitFactor(_ name: String) -> (kind: String, factor: Double)? { units[name] }

    private static func temperature(_ name: String) -> Character? {
        switch name {
        case "c", "°c", "celsius": return "c"
        case "f", "°f", "fahrenheit": return "f"
        case "k", "kelvin": return "k"
        default: return nil
        }
    }

    private static func unitAnswer(_ s: String) -> Answer? {
        guard let (amount, from, to) = splitConversion(s) else { return nil }
        let value: Double
        if let a = temperature(from), let b = temperature(to) {
            let kelvin = a == "c" ? amount + 273.15 : a == "f" ? (amount - 32) * 5 / 9 + 273.15 : amount
            value = b == "c" ? kelvin - 273.15 : b == "f" ? (kelvin - 273.15) * 9 / 5 + 32 : kelvin
        } else if let a = unitFactor(from), let b = unitFactor(to), a.kind == b.kind {
            value = amount * a.factor / b.factor
        } else {
            return nil
        }
        return Answer(text: format(value, maxFraction: 4) + " " + to, value: value)
    }

    // MARK: - Dates

    private static func dateAnswer(_ s: String, now: Date) -> Answer? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        // "30 hari lagi", "2 weeks from now", "3 bulan yang lalu", "10 days ago"
        if let m = s.wholeMatch(
            of: #/(\d+)\s*(hari|days?|minggu|weeks?|bulan|months?|tahun|years?)\s+(lagi|dari sekarang|from now|later|yang lalu|lalu|ago)/#),
            let n = Int(m.1)
        {
            let sign = ["yang lalu", "lalu", "ago"].contains(String(m.3)) ? -1 : 1
            let component: Calendar.Component =
                switch String(m.2).prefix(3) {
                case "har", "day": .day
                case "min", "wee": .weekOfYear
                case "bul", "mon": .month
                default: .year
                }
            guard let date = cal.date(byAdding: component, value: sign * n, to: today) else { return nil }
            return Answer(text: longDate(date), value: nil)
        }
        // "hari sampai 25 des", "berapa hari ke 17 agustus", "days until 2027-01-01"
        if let m = s.wholeMatch(of: #/(?:berapa\s+)?(?:hari|days)\s+(?:sampai|ke|menuju|until|till|to)\s+(.+?)\??/#),
            let date = parseDate(String(m.1), today: today, future: true)
        {
            return days(from: today, to: date)
        }
        // "dari 1 jan 2026 sampai 31 mar 2026", "between 2026-01-01 and 2026-02-01"
        if let m = s.wholeMatch(of: #/(?:hari\s+)?(?:dari|from|between)\s+(.+?)\s+(?:sampai|hingga|to|and)\s+(.+?)/#),
            let a = parseDate(String(m.1), today: today, future: false),
            let b = parseDate(String(m.2), today: today, future: false)
        {
            return days(from: a, to: b)
        }
        // "umur 1999-05-10", "age 10/05/1999"
        if let m = s.wholeMatch(of: #/(?:umur|usia|age)\s+(.+)/#),
            let birth = parseDate(String(m.1), today: today, future: false), birth <= today
        {
            let d = cal.dateComponents([.year, .month, .day], from: birth, to: today)
            let years = d.year ?? 0
            return Answer(text: "\(years) yr \(d.month ?? 0) mo \(d.day ?? 0) d", value: Double(years))
        }
        if let date = parseDate(s, today: today, future: false), s.wholeMatch(of: #/[a-z ]+/#) != nil {
            return Answer(text: longDate(date), value: nil) // "hari ini", "besok", "tomorrow"
        }
        return nil
    }

    private static func days(from a: Date, to b: Date) -> Answer {
        let n = Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0
        let weeks = abs(n) >= 7 ? " · \(abs(n) / 7) wk \(abs(n) % 7) d" : ""
        return Answer(text: "\(n) days" + weeks, value: Double(n))
    }

    private static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).year())
    }

    private static let monthPrefixes: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "mei": 5, "may": 5, "jun": 6, "jul": 7, "agu": 8, "ags": 8,
        "aug": 8, "sep": 9, "okt": 10, "oct": 10, "nov": 11, "des": 12, "dec": 12,
    ]

    /// "2026-12-25", "25/12/2026", "25 des [2026]", "hari ini", "besok"…
    /// A day-month without a year means the next one when `future`, else this year's.
    static func parseDate(_ s: String, today: Date, future: Bool) -> Date? {
        let cal = Calendar.current
        let s = s.trimmingCharacters(in: .whitespaces)
        switch s {
        case "hari ini", "today", "sekarang", "now": return today
        case "besok", "tomorrow": return cal.date(byAdding: .day, value: 1, to: today)
        case "kemarin", "yesterday": return cal.date(byAdding: .day, value: -1, to: today)
        case "lusa": return cal.date(byAdding: .day, value: 2, to: today)
        default: break
        }
        var y: Int?, mo: Int?, d: Int?
        if let m = s.wholeMatch(of: #/(\d{4})-(\d{1,2})-(\d{1,2})/#) {
            (y, mo, d) = (Int(m.1), Int(m.2), Int(m.3))
        } else if let m = s.wholeMatch(of: #/(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})/#) {
            (y, mo, d) = (Int(m.3), Int(m.2), Int(m.1))
        } else if let m = s.wholeMatch(of: #/(\d{1,2})\s+([a-z]{3,})(?:\s+(\d{4}))?/#) {
            (y, mo, d) = (m.3.flatMap { Int($0) }, monthPrefixes[String(m.2.prefix(3))], Int(m.1))
        } else {
            return nil
        }
        guard let mo, let d, (1...12).contains(mo), (1...31).contains(d) else { return nil }
        let thisYear = cal.component(.year, from: today)
        guard var date = cal.date(from: DateComponents(year: y ?? thisYear, month: mo, day: d)),
            cal.component(.day, from: date) == d // rejects 31 feb
        else { return nil }
        if y == nil, future, date < today, let next = cal.date(byAdding: .year, value: 1, to: date) { date = next }
        return date
    }

    static func format(_ value: Double, currency: String? = nil, maxFraction: Int = 10) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = currency == "IDR" || currency == "JPY" ? 0 : (currency == nil ? maxFraction : 2)
        f.minimumFractionDigits = currency == nil || currency == "IDR" || currency == "JPY" ? 0 : 2
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    #if DEBUG
    static func selfCheck() {
        assert(evaluate("2+3*4") == 14)
        assert(evaluate("(2+3)*4") == 20)
        assert(evaluate("2^3^2") == 512)
        assert(evaluate("-2^2") == 4) // unary binds tighter, like a calculator keypad
        assert(evaluate("50%*200") == 100)
        assert(evaluate("sqrt(16)+abs(-1)") == 5)
        assert(evaluate("2jt/4") == 500_000)
        assert(evaluate("1,5*2") == 3)
        assert(evaluate("1/0") == nil)
        assert(evaluate("2+") == nil)
        assert(evaluate("foo(1)") == nil)
        assert(parseConversion("100 usd to idr") == Conversion(amount: 100, from: "USD", to: "IDR"))
        assert(parseConversion("2*5rb idr ke usd") == Conversion(amount: 10_000, from: "IDR", to: "USD"))
        assert(parseConversion("100 to idr") == nil)
        assert(parseConversion("60 min to sec") == nil)
        assert(parseConversion("100usd to idr") == Conversion(amount: 100, from: "USD", to: "IDR"))

        func near(_ a: Double?, _ b: Double) -> Bool { a.map { abs($0 - b) < 1e-6 * max(1, abs(b)) } ?? false }
        // Phrases
        assert(evaluate("200-50%") == 100)
        assert(near(evaluate("200 + 10%"), 220))
        assert(evaluate("15% dari 200rb") == 30_000)
        assert(near(evaluate("diskon 30% dari 1,5jt"), 1_050_000))
        assert(near(evaluate("1,5jt diskon 30%"), 1_050_000))
        assert(near(evaluate("20% off 100"), 80))
        assert(near(evaluate("200rb + ppn 11%"), 222_000))
        assert(near(evaluate("naik 10% dari 5jt"), 5_500_000))
        assert(evaluate("1.500.000/2") == 750_000)
        assert(smart("50 dari 200 berapa persen")?.value == 25)
        assert(smart("30 is what % of 120")?.value == 25)
        // Units
        assert(abs((smart("5 km to mi")?.value ?? 0) - 3.106856) < 1e-5)
        assert(near(smart("100 c to f")?.value, 212))
        assert(smart("1 gb to mb")?.value == 1024)
        assert(smart("90 min ke jam")?.value == 1.5)
        assert(smart("5km to m")?.value == 5000)
        assert(smart("5 kg to idr") == nil)
        assert(smart("100 usd to idr") == nil)
        // Dates, from a fixed "today" of 2 Nov 2026
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 15))!
        assert(smart("hari sampai 25 des", now: now)?.value == 53)
        assert(smart("days until 1 jan", now: now)?.value == 60)
        assert(smart("dari 2026-01-01 sampai 2026-01-31", now: now)?.value == 30)
        assert(smart("umur 2000-11-02", now: now)?.value == 26)
        assert(smart("umur 31/02/2000", now: now) == nil)
        assert(smart("30 hari lagi", now: now)?.text.contains("2026") == true)
        assert(smart("besok", now: now) != nil)
        assert(smart("2+2", now: now) == nil)
    }
    #endif
}
