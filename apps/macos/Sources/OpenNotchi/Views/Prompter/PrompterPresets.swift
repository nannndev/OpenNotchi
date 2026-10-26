import Foundation

/// Preset teleprompter scripts for fast rehearsal and presentations.
struct PrompterTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let script: String
}

enum PrompterPresets {
    static let all: [PrompterTemplate] = [
        PrompterTemplate(
            title: "Elevator Pitch (30s)",
            icon: "bolt.fill",
            script: """
                Hi everyone, thank you for your time today!

                [Look right at this camera line — your gaze is 100% natural]

                OpenNotchi transforms your MacBook notch into a living, intelligent dynamic hub.

                From spinning turntable vinyl decks with haptic grooves, to synced karaoke lyrics, developer tools, and this real-time eye-contact teleprompter — it turns unused screen space into your favorite daily companion.

                It's lightweight, open source, and built natively with Swift and Metal.

                I'd love to show you a quick demo right now!
                """
        ),
        PrompterTemplate(
            title: "Daily Standup Update",
            icon: "person.3.fill",
            script: """
                Good morning team! Here's a quick update on my end:

                [Keep your eyes pinned to the camera lens above]

                Yesterday:
                • Finalized the new release pipeline and resolved all CI edge cases.
                • Polished the audio routing and developer tools tab.

                Today:
                • Integrating the new eye-contact teleprompter for video meetings.
                • Running regression tests and publishing the latest universal build.

                Blockers:
                • None on my side. All green and ready to roll!
                """
        ),
        PrompterTemplate(
            title: "Product Walkthrough",
            icon: "macbook",
            script: """
                Welcome everyone to today's feature demonstration!

                Over the next few minutes, we're exploring our most requested capability: the Camera Eye-Contact Teleprompter.

                Notice how natural my eye contact feels right now. Instead of glancing down at notes or looking off to a second monitor, my script scrolls right under the webcam lens.

                You can adjust scrolling speed on the fly, switch between stealth frosted glass and camera preview, and paste your own meeting notes in seconds.

                Let's dive into the live walkthrough!
                """
        ),
        PrompterTemplate(
            title: "Job Interview Intro",
            icon: "briefcase.fill",
            script: """
                Thank you so much for the invitation to speak with you today!

                [Smile and maintain steady eye contact with the camera]

                My background centers around building high-impact software experiences with an obsessive focus on performance, intuitive design, and clean architecture.

                Over the past few years, I've led projects from zero to production — working with Swift, macOS system frameworks, and modern full-stack web applications.

                What excites me most about this role is the opportunity to solve hard problems alongside a world-class team.

                I'm looking forward to diving into the details today!
                """
        ),
        PrompterTemplate(
            title: "Keynote / Speech Opening",
            icon: "sparkles",
            script: """
                Good afternoon, everyone!

                Have you ever noticed how disconnected virtual meetings feel when people keep looking down at their notes?

                Today, we are changing that.

                Technology should work for us, not distract us. By placing your thoughts right where your audience is looking, communication becomes effortless, authentic, and engaging.

                Let's take a closer look at what we've built together.
                """
        ),
    ]
}
