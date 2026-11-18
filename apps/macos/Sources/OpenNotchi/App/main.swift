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

// Accessory apps show no menu bar, but Cmd+C/V/X/A/Z only reach text fields through the main
// menu's key equivalents; without this Edit menu, pasting an API key does nothing.
let mainMenu = NSMenu()
let editItem = NSMenuItem()
editItem.submenu = {
    let m = NSMenu(title: "Edit")
    m.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    m.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    m.addItem(.separator())
    m.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    m.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    m.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    m.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    return m
}()
mainMenu.addItem(editItem)
app.mainMenu = mainMenu

app.run()
