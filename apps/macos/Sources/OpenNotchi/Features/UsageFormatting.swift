import Foundation

/// 1234 → "1.2K", 93176220 → "93M".
func formatTokens(_ n: Int) -> String {
    guard n >= 1000 else { return "\(n)" }
    let (v, unit): (Double, String) = n < 1_000_000 ? (Double(n) / 1e3, "K") : n < 1_000_000_000 ? (Double(n) / 1e6, "M") : (Double(n) / 1e9, "B")
    return (v < 10 ? String(format: "%.1f", v) : "\(Int(v.rounded()))").replacingOccurrences(of: ".0", with: "") + unit
}

func formatCost(_ usd: Double) -> String {
    usd >= 100 ? "$\(Int(usd.rounded()))" : String(format: "$%.2f", usd)
}

/// "resets in 3h 20m" / "resets in 2d".
func resetsIn(_ date: Date, now: Date = .now) -> String {
    let m = max(0, Int((date.timeIntervalSince(now) / 60).rounded()))
    if m >= 2880 { return "resets in \(Int((Double(m) / 1440).rounded()))d" }
    if m >= 60 { return "resets in \(m / 60)h" + (m % 60 > 0 ? " \(m % 60)m" : "") }
    return "resets in \(m)m"
}

/// Formats reset countdown with both relative duration and exact local time:
/// "Resets in 1h 25m (10:00)" or "Resets in 2d (28 Oct, 23:00)".
func formatResetDetail(_ date: Date, now: Date = .now) -> String {
    let m = max(0, Int((date.timeIntervalSince(now) / 60).rounded()))
    let timeFormatter = DateFormatter()
    timeFormatter.locale = Locale.current
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)
        if m >= 60 {
            let h = m / 60
            let remM = m % 60
            let countdown = remM > 0 ? "\(h)h \(remM)m" : "\(h)h"
            return "Resets in \(countdown) (\(timeStr))"
        } else {
            return "Resets in \(m)m (\(timeStr))"
        }
    } else {
        timeFormatter.dateFormat = "d MMM, HH:mm"
        let dateStr = timeFormatter.string(from: date)
        let days = max(1, Int((Double(m) / 1440.0).rounded()))
        return "Resets in \(days)d (\(dateStr))"
    }
}
