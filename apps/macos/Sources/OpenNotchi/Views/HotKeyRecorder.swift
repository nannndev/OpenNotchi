import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press a key combination to set the notch shortcut. Esc cancels.
struct HotKeyRecorder: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? "Press keys…" : settings.hotKeyDisplay)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(minWidth: 90)
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? .accentColor : nil)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        AppDelegate.shared?.suspendHotKey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            // Require a real modifier so plain typing can't become the shortcut.
            guard !flags.intersection([.command, .option, .control]).isEmpty else {
                NSSound.beep()
                return nil
            }
            let key = event.charactersIgnoringModifiers?.uppercased() ?? "?"
            settings.setHotKey(code: Int(event.keyCode), modifiers: Self.carbonModifiers(flags), display: Self.symbols(flags) + key)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording { AppDelegate.shared?.updateHotKey() }
        isRecording = false
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.shift) { result |= shiftKey }
        return result
    }

    private static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }
}
