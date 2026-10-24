import AppKit

#if DEBUG
if let i = CommandLine.arguments.firstIndex(of: "--ai-selftest") {
    AISelfTest.run(Array(CommandLine.arguments[(i + 1)...]))
}
#endif

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
