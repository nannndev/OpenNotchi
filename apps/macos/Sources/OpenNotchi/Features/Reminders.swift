import AppKit
import EventKit
import SwiftUI

/// Shows banners for upcoming calendar events and prayer times.
final class ReminderCenter {
    var onBanner: ((Banner) -> Void)?

    private let settings: AppSettings
    private let calendar: CalendarManager
    private let prayers: PrayerTimesManager
    private var timer: Timer?
    /// Keys of reminders already shown, so each fires once.
    private var fired: Set<String> = []

    /// A reminder whose moment passed longer ago than this (e.g. while asleep) is skipped.
    private static let staleAfter: TimeInterval = 90

    init(settings: AppSettings, calendar: CalendarManager, prayers: PrayerTimesManager) {
        self.settings = settings
        self.calendar = calendar
        self.prayers = prayers
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.check() }
        timer?.tolerance = 3
    }

    func check(now: Date = .now) {
        checkEvents(now: now)
        checkPrayers(now: now)
        if fired.count > 200 { fired.removeAll() }
    }

    private func checkEvents(now: Date) {
        let lead = TimeInterval(settings.meetingReminderMinutes * 60)
        guard lead > 0, calendar.hasAccess else { return }
        for event in calendar.events {
            guard let start = event.startDate else { continue }
            let fireAt = start.addingTimeInterval(-lead)
            guard isDue(fireAt, now: now) else { continue }
            let link = MeetingLinks.link(for: event)
            if settings.meetingRemindersOnlyWithLink && link == nil { continue }
            let key = "event-\(event.calendarItemIdentifier)-\(Int(start.timeIntervalSince1970))"
            guard fired.insert(key).inserted else { continue }
            show(Self.eventBanner(title: event.title, start: start, now: now, link: link, color: event.calendar.map { Color(cgColor: $0.cgColor) }))
        }
    }

    private func checkPrayers(now: Date) {
        guard settings.prayerEnabled else { return }
        let lead = TimeInterval(settings.prayerReminderMinutes * 60)
        let place = settings.weatherPlace
        for prayer in prayers.today {
            if settings.prayerNotify, isDue(prayer.date, now: now), fired.insert("prayer-\(prayer.id)").inserted {
                show(Self.prayerBanner(prayer, name: prayers.name(prayer.kind), place: place, minutesLeft: 0, indonesian: settings.prayerIndonesianNames))
            }
            if lead > 0, isDue(prayer.date.addingTimeInterval(-lead), now: now), fired.insert("prayer-early-\(prayer.id)").inserted {
                show(Self.prayerBanner(prayer, name: prayers.name(prayer.kind), place: place, minutesLeft: settings.prayerReminderMinutes, indonesian: settings.prayerIndonesianNames))
            }
        }
    }

    private func isDue(_ date: Date, now: Date) -> Bool {
        date <= now && now.timeIntervalSince(date) < Self.staleAfter
    }

    private func show(_ banner: Banner) {
        // The banner plays its own sound when notification sounds are on; this setting keeps reminders quiet otherwise.
        var banner = banner
        if !settings.reminderSound { banner.kind = .info }
        onBanner?(banner)
    }

    // MARK: - Banners

    static func eventBanner(title: String?, start: Date, now: Date = .now, link: (url: URL, service: String)?, color: Color?) -> Banner {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded())
        return Banner(
            icon: link == nil ? "calendar" : "video.fill",
            tint: color ?? .blue,
            badge: minutes <= 0 ? "now" : "in \(minutes) min",
            title: title ?? "Untitled event",
            subtitle: start.formatted(date: .omitted, time: .shortened) + (link.map { " · \($0.service)" } ?? ""),
            actionTitle: link == nil ? nil : "Join",
            actionURL: link?.url,
            kind: minutes <= 0 ? .attention : .reminder
        )
    }

    /// Indonesian names come with Indonesian phrasing, so the banner never mixes languages.
    static func prayerBanner(_ prayer: PrayerTime, name: String, place: String, minutesLeft: Int, indonesian: Bool) -> Banner {
        let time = prayer.date.formatted(date: .omitted, time: .shortened)
        let title: String
        if minutesLeft > 0 {
            title = indonesian ? "\(name) \(minutesLeft) menit lagi" : "\(name) in \(minutesLeft) min"
        } else if prayer.kind == .maghrib && PrayerTimesManager.isRamadan {
            title = indonesian ? "Maghrib · waktunya berbuka" : "Maghrib · time to break the fast"
        } else if prayer.kind == .imsak {
            title = "Imsak"
        } else {
            title = indonesian ? "Waktunya sholat \(name)" : "Time for \(name)"
        }
        return Banner(
            icon: prayer.kind.symbol,
            tint: .teal,
            badge: time,
            title: title,
            subtitle: place.isEmpty ? nil : place,
            kind: .reminder
        )
    }
}
