import EventKit
import SwiftUI

struct CalendarWidget: View {
    @EnvironmentObject private var calendar: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Date.now, format: .dateTime.day())
                    .font(.system(size: 26, weight: .bold))
                VStack(alignment: .leading, spacing: 0) {
                    Text(Date.now, format: .dateTime.weekday(.wide))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(Date.now, format: .dateTime.month(.wide))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if calendar.hasAccess {
                if calendar.events.isEmpty {
                    Text("No more events today")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(calendar.events.prefix(3), id: \.eventIdentifier) { event in
                        EventRow(event: event)
                    }
                }
            } else if calendar.canRequestAccess {
                Button("Connect Calendar") { calendar.requestAccess() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.12)))
            } else {
                Text("Allow Calendar access in System Settings → Privacy")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 6)
    }
}

private struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(event.startDate, format: .dateTime.hour().minute())
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
