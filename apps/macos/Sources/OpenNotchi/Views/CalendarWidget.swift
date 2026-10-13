import EventKit
import SwiftUI

/// Symmetrical 112x112 desk calendar card that perfectly balances the album art/vinyl turntable on the left.
struct CalendarWidget: View {
    @EnvironmentObject private var calendar: CalendarManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            if calendar.hasAccess && !calendar.events.isEmpty {
                eventsView
            } else {
                deskCalendarView
            }
        }
        .frame(width: 112, height: 112)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHovering ? .white.opacity(0.24) : .white.opacity(0.12), lineWidth: 0.5)
                )
        }
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onHover { isHovering = $0 }
        .onTapGesture {
            openCalendarApp()
        }
        .contextMenu {
            Button {
                openCalendarApp()
            } label: {
                Label("Open Calendar", systemImage: "calendar")
            }

            Button {
                calendar.reload()
            } label: {
                Label("Reload Events", systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    settings.calendarEnabled = false
                    settings.audioDeckEnabled = false
                }
            } label: {
                Label("Hide Calendar Widget", systemImage: "eye.slash")
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    settings.calendarEnabled = false
                    settings.audioDeckEnabled = true
                }
            } label: {
                Label("Switch to Audio Spectrum Deck", systemImage: "waveform")
            }
        }
        .help("Calendar Widget • Click to open Calendar, right-click for options")
    }

    // MARK: - Desk Calendar (Standard Date & Status / Connect)
    private var deskCalendarView: some View {
        VStack(spacing: 0) {
            // Header: Day of week + Month
            HStack(alignment: .center) {
                Text(Date.now, format: .dateTime.weekday(.wide))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text(Date.now, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            .padding(.top, 9)
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            // Big Bold Day Number
            Text(Date.now, format: .dateTime.day())
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            // Footer Action / Status
            Group {
                if calendar.hasAccess {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                        Text("All clear today")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(.white.opacity(0.06)))
                } else if calendar.canRequestAccess {
                    Button {
                        calendar.requestAccess()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 9))
                            Text("Connect")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.12)))
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Connect Apple Calendar")
                } else {
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 8))
                            Text("Enable")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Allow Calendar access in Settings")
                }
            }
            .padding(.bottom, 9)
            .padding(.horizontal, 10)
        }
    }

    // MARK: - Upcoming Events View
    private var eventsView: some View {
        let firstEvent = calendar.events.first!
        let eventColor = Color(cgColor: firstEvent.calendar.cgColor)

        return VStack(alignment: .leading, spacing: 0) {
            // Header: Date + Event Start Time Badge
            HStack(alignment: .center, spacing: 4) {
                Text(Date.now, format: .dateTime.weekday(.abbreviated).day())
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.red)
                    .textCase(.uppercase)

                Spacer()

                Text(firstEvent.startDate, format: .dateTime.hour().minute())
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(eventColor.opacity(0.35)))
            }
            .padding(.top, 9)
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            // Event Details: Title & Color Strip
            HStack(alignment: .top, spacing: 5) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(eventColor)
                    .frame(width: 2.5, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(firstEvent.title ?? "Untitled")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let loc = firstEvent.location, !loc.isEmpty {
                        Text(loc)
                            .font(.system(size: 8.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            // Footer: Join button or event count
            HStack(alignment: .center) {
                if let link = MeetingLinks.link(for: firstEvent) {
                    Button {
                        NSWorkspace.shared.open(link.url)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text("Join")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.green))
                    }
                    .buttonStyle(.plain)
                    .help("Join on \(link.service)")
                }

                Spacer()

                if calendar.events.count > 1 {
                    Text("+\(calendar.events.count - 1) more")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Today")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 9)
            .padding(.horizontal, 10)
        }
    }

    private func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        }
    }
}
