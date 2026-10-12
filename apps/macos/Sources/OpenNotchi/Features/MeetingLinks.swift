import EventKit
import Foundation

/// Finds the video call link in a calendar event (URL, location or notes).
enum MeetingLinks {
    struct Service {
        let name: String
        let hosts: [String]
    }

    static let services = [
        Service(name: "Zoom", hosts: ["zoom.us", "zoomgov.com"]),
        Service(name: "Google Meet", hosts: ["meet.google.com"]),
        Service(name: "Teams", hosts: ["teams.microsoft.com", "teams.live.com"]),
        Service(name: "Webex", hosts: ["webex.com"]),
        Service(name: "FaceTime", hosts: ["facetime.apple.com"]),
        Service(name: "Slack", hosts: ["app.slack.com"]),
        Service(name: "Whereby", hosts: ["whereby.com"]),
        Service(name: "Jitsi", hosts: ["meet.jit.si"]),
        Service(name: "Discord", hosts: ["discord.gg", "discord.com"]),
    ]

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func link(for event: EKEvent) -> (url: URL, service: String)? {
        let text = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        return link(in: text)
    }

    static func link(in text: String) -> (url: URL, service: String)? {
        guard let detector else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url, let host = url.host?.lowercased(), url.scheme?.hasPrefix("http") == true else { continue }
            if let service = services.first(where: { $0.hosts.contains { host == $0 || host.hasSuffix("." + $0) } }) {
                return (url, service.name)
            }
        }
        return nil
    }
}
