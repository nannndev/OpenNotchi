import Combine
import Foundation

enum PrayerKind: String, CaseIterable {
    case imsak, fajr, sunrise, dhuhr, asr, maghrib, isha

    /// Sunrise is listed for reference only; it is not a prayer and never notifies.
    var isPrayer: Bool { self != .sunrise && self != .imsak }

    func name(indonesian: Bool) -> String {
        switch self {
        case .imsak: return "Imsak"
        case .fajr: return indonesian ? "Subuh" : "Fajr"
        case .sunrise: return indonesian ? "Terbit" : "Sunrise"
        case .dhuhr: return indonesian ? "Dzuhur" : "Dhuhr"
        case .asr: return indonesian ? "Ashar" : "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return indonesian ? "Isya" : "Isha"
        }
    }

    var symbol: String {
        switch self {
        case .imsak: return "moon.haze.fill"
        case .fajr: return "sun.horizon.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}

struct PrayerTime: Equatable, Identifiable {
    let kind: PrayerKind
    let date: Date
    var id: String { "\(kind.rawValue)-\(Int(date.timeIntervalSince1970))" }
}

/// Calculation conventions. Angles are the sun's depression below the horizon.
enum PrayerMethod: String, CaseIterable, Identifiable {
    case kemenag, mwl, isna, egypt, ummAlQura, jakim, diyanet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kemenag: return "Kemenag (Indonesia)"
        case .mwl: return "Muslim World League"
        case .isna: return "ISNA (North America)"
        case .egypt: return "Egyptian General Authority"
        case .ummAlQura: return "Umm al-Qura (Makkah)"
        case .jakim: return "JAKIM (Malaysia) / MUIS (Singapore)"
        case .diyanet: return "Diyanet (Türkiye)"
        }
    }

    var fajrAngle: Double {
        switch self {
        case .kemenag, .jakim: return 20
        case .mwl, .diyanet: return 18
        case .isna: return 15
        case .egypt: return 19.5
        case .ummAlQura: return 18.5
        }
    }

    /// Isha angle, or nil when Isha is a fixed time after Maghrib.
    var ishaAngle: Double? {
        switch self {
        case .kemenag, .jakim: return 18
        case .mwl, .diyanet: return 17
        case .isna: return 15
        case .egypt: return 17.5
        case .ummAlQura: return nil
        }
    }

    /// Minutes added as a safety margin (ihtiyat). Kemenag's published tables use 2 minutes,
    /// and 3 for Dhuhr and Maghrib.
    func safetyMinutes(for kind: PrayerKind) -> Double {
        switch self {
        case .kemenag, .jakim: return kind == .dhuhr || kind == .maghrib ? 3 : 2
        default: return 0
        }
    }

    /// The method most people in the current region use.
    static var regionalDefault: PrayerMethod {
        switch Locale.current.region?.identifier {
        case "ID": return .kemenag
        case "MY", "SG", "BN": return .jakim
        case "US", "CA": return .isna
        case "SA", "AE", "QA", "KW", "BH", "OM", "YE": return .ummAlQura
        case "EG", "SD", "LY", "SY", "LB", "IQ", "JO": return .egypt
        case "TR": return .diyanet
        default: return .mwl
        }
    }
}

/// Astronomical prayer time calculation (the PrayTimes.org algorithm). Runs fully offline.
enum PrayerCalculator {
    /// Times for the given calendar day at a location. `hanafiAsr` uses a shadow factor of 2.
    static func times(on day: Date, latitude: Double, longitude: Double, method: PrayerMethod, hanafiAsr: Bool, calendar: Calendar = .current) -> [PrayerTime] {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return [] }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let midnight = utc.date(from: DateComponents(year: year, month: month, day: day)) else { return [] }

        let jd = julianDate(year: year, month: month, day: day) - longitude / (15 * 24)
        let lat = latitude

        func sun(_ t: Double) -> (decl: Double, eqt: Double) {
            let d = jd + t - 2451545.0
            let g = fixAngle(357.529 + 0.98560028 * d)
            let q = fixAngle(280.459 + 0.98564736 * d)
            let l = fixAngle(q + 1.915 * sin(deg: g) + 0.020 * sin(deg: 2 * g))
            let e = 23.439 - 0.00000036 * d
            let ra = atan2(deg: cos(deg: e) * sin(deg: l), cos(deg: l)) / 15
            return (asin(deg: sin(deg: e) * sin(deg: l)), q / 15 - fixHour(ra))
        }
        func midDay(_ t: Double) -> Double { fixHour(12 - sun(t).eqt) }
        /// Hours (local solar) when the sun is `angle` degrees below the horizon; nil near the poles.
        func sunAngleTime(_ angle: Double, _ t: Double, ccw: Bool) -> Double? {
            let decl = sun(t).decl
            let cosT = (-sin(deg: angle) - sin(deg: decl) * sin(deg: lat)) / (cos(deg: decl) * cos(deg: lat))
            guard (-1...1).contains(cosT) else { return nil }
            let delta = acos(deg: cosT) / 15
            return midDay(t) + (ccw ? -delta : delta)
        }
        func asrTime(_ factor: Double, _ t: Double) -> Double? {
            let decl = sun(t).decl
            let angle = -atan(deg: 1 / (factor + tan(deg: abs(lat - decl))))
            return sunAngleTime(angle, t, ccw: false)
        }

        // One refinement pass from rough guesses (fractions of a day) is accurate to well under a minute.
        let horizon = 0.833
        let fajr = sunAngleTime(method.fajrAngle, 5.0 / 24, ccw: true)
        let sunrise = sunAngleTime(horizon, 6.0 / 24, ccw: true)
        let dhuhr = midDay(12.0 / 24)
        let asr = asrTime(hanafiAsr ? 2 : 1, 13.0 / 24)
        let sunset = sunAngleTime(horizon, 18.0 / 24, ccw: false)
        let isha = method.ishaAngle.flatMap { sunAngleTime($0, 18.0 / 24, ccw: false) } ?? sunset.map { $0 + 1.5 }

        let raw: [(PrayerKind, Double?)] = [
            (.fajr, fajr), (.sunrise, sunrise), (.dhuhr, dhuhr), (.asr, asr), (.maghrib, sunset), (.isha, isha),
        ]
        var result: [PrayerTime] = raw.compactMap { kind, hours in
            guard let hours else { return nil }
            // The margin makes prayers later, but sunrise (the end of Fajr) earlier.
            let margin = method.safetyMinutes(for: kind) / 60 * (kind == .sunrise ? -1 : 1)
            let utcHours = hours - longitude / 15 + margin
            // Round up to the whole minute, as published timetables do.
            let seconds = (utcHours * 3600 / 60).rounded(.up) * 60
            return PrayerTime(kind: kind, date: midnight.addingTimeInterval(seconds))
        }
        if let fajrTime = result.first(where: { $0.kind == .fajr }) {
            result.insert(PrayerTime(kind: .imsak, date: fajrTime.date.addingTimeInterval(-10 * 60)), at: 0)
        }
        return result
    }

    private static func julianDate(year: Int, month: Int, day: Int) -> Double {
        var y = Double(year), m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + Double(day) + b - 1524.5
    }

    private static func fixAngle(_ a: Double) -> Double { a - 360 * floor(a / 360) }
    private static func fixHour(_ h: Double) -> Double { h - 24 * floor(h / 24) }
    private static func sin(deg: Double) -> Double { Foundation.sin(deg * .pi / 180) }
    private static func cos(deg: Double) -> Double { Foundation.cos(deg * .pi / 180) }
    private static func tan(deg: Double) -> Double { Foundation.tan(deg * .pi / 180) }
    private static func asin(deg x: Double) -> Double { Foundation.asin(x) * 180 / .pi }
    private static func acos(deg x: Double) -> Double { Foundation.acos(x) * 180 / .pi }
    private static func atan(deg x: Double) -> Double { Foundation.atan(x) * 180 / .pi }
    private static func atan2(deg y: Double, _ x: Double) -> Double { Foundation.atan2(y, x) * 180 / .pi }
}

/// Today's prayer times for the location chosen in Settings (shared with weather).
final class PrayerTimesManager: ObservableObject {
    @Published private(set) var today: [PrayerTime] = []
    /// The next prayer (Imsak only during Ramadan), possibly tomorrow's Fajr.
    @Published private(set) var next: PrayerTime?

    private let settings: AppSettings
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings) {
        self.settings = settings
        Publishers.CombineLatest4(settings.$weatherPlace, settings.$prayerEnabled, settings.$prayerMethod, settings.$hanafiAsr)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
    }

    var hasLocation: Bool { !settings.weatherPlace.isEmpty }

    /// True during the month of Ramadan, when Imsak is shown and notified.
    static var isRamadan: Bool {
        Calendar(identifier: .islamicUmmAlQura).component(.month, from: .now) == 9
    }

    func name(_ kind: PrayerKind) -> String {
        kind.name(indonesian: settings.prayerIndonesianNames)
    }

    /// Times shown and notified: prayers, plus Imsak in Ramadan.
    func schedule(on day: Date) -> [PrayerTime] {
        guard settings.prayerEnabled, hasLocation else { return [] }
        return PrayerCalculator.times(
            on: day,
            latitude: settings.weatherLatitude,
            longitude: settings.weatherLongitude,
            method: settings.prayerMethod,
            hanafiAsr: settings.hanafiAsr
        )
        .filter { $0.kind.isPrayer || ($0.kind == .imsak && Self.isRamadan) }
    }

    func refresh() {
        let now = Date()
        let todays = schedule(on: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now).map(schedule(on:)) ?? []
        let upcoming = (todays + tomorrow).first { $0.date > now }
        if todays != today { today = todays }
        if upcoming != next { next = upcoming }
    }
}
