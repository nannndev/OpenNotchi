import AppKit

#if DEBUG
if let i = CommandLine.arguments.firstIndex(of: "--ai-selftest") {
    AISelfTest.run(Array(CommandLine.arguments[(i + 1)...]))
}
if let i = CommandLine.arguments.firstIndex(of: "--strip-snapshot") {
    StripSnapshot.run(Array(CommandLine.arguments[(i + 1)...]))
}
if CommandLine.arguments.contains("--calc-selftest") {
    Calculator.selfCheck()
    MainActor.assumeIsolated { NoteStore.selfCheck() }
    print("calculator & notes ok")
    exit(0)
}
#endif

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
