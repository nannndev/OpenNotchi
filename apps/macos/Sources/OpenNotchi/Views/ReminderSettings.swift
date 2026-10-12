import SwiftUI

/// Calendar event reminders.
struct MeetingReminderSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var calendar: CalendarManager

    var body: some View {
        Picker("Remind me before events", selection: $settings.meetingReminderMinutes) {
            Text("Off").tag(0)
            ForEach([1, 2, 5, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
        }
        if settings.meetingReminderMinutes > 0 {
            Toggle("Only events with a video call link", isOn: $settings.meetingRemindersOnlyWithLink)
            if !calendar.hasAccess {
                HStack {
                    Label("Needs Calendar access.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    if calendar.canRequestAccess {
                        Button("Connect Calendar") { calendar.requestAccess() }
                            .controlSize(.small)
                    } else {
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        Toggle("Play a sound with reminders", isOn: $settings.reminderSound)
        Text("Zoom, Google Meet, Teams, Webex and FaceTime links get a Join button.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// Prayer times in the header, with a reminder at each prayer.
struct PrayerSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var prayers: PrayerTimesManager

    var body: some View {
        Toggle("Show prayer times", isOn: $settings.prayerEnabled)
        if settings.prayerEnabled {
            Picker("Calculation method", selection: $settings.prayerMethod) {
                ForEach(PrayerMethod.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Asr", selection: $settings.hanafiAsr) {
                Text("Standard (Shafi'i, Maliki, Hanbali)").tag(false)
                Text("Hanafi").tag(true)
            }
            Picker("Names", selection: $settings.prayerIndonesianNames) {
                Text("Fajr, Dhuhr, Asr…").tag(false)
                Text("Subuh, Dzuhur, Ashar…").tag(true)
            }
            Toggle("Notify at each prayer time", isOn: $settings.prayerNotify)
            Picker("Heads-up before", selection: $settings.prayerReminderMinutes) {
                Text("Off").tag(0)
                ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
            }

            if prayers.hasLocation {
                LabeledContent("Today in \(settings.weatherPlace)") {
                    HStack(spacing: 12) {
                        ForEach(prayers.today) { prayer in
                            VStack(spacing: 2) {
                                Text(prayers.name(prayer.kind))
                                    .font(.caption)
                                    .foregroundStyle(prayer == prayers.next ? Color.accentColor : .secondary)
                                Text(prayer.date, format: .dateTime.hour().minute())
                                    .font(.callout.monospacedDigit())
                                    .fontWeight(prayer == prayers.next ? .semibold : .regular)
                            }
                        }
                    }
                }
                Text("Calculated on your Mac from the location above. Times can differ by a minute or two from your local mosque. Imsak is added during Ramadan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Set a location above to see prayer times.", systemImage: "location.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
