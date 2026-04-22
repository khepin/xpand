import AppKit
import CoreGraphics

final class Expander {
    private let engine: JSEngine
    private let sound: NSSound?

    init(engine: JSEngine, soundPath: String?) {
        self.engine = engine
        if let path = soundPath {
            self.sound = NSSound(contentsOfFile: path, byReference: true)
        } else {
            self.sound = nil
        }
    }

    func expand(trigger: String) {
        guard let replacement = engine.expand(trigger: trigger) else { return }

        // Delete the trigger characters (minus 1 because the last keystroke was already suppressed)
        let deleteCount = trigger.count - 1
        injectBackspaces(count: deleteCount)
        usleep(10_000) // 10ms settling time

        // Paste replacement via clipboard
        pasteText(replacement)

        // Play sound
        sound?.stop()
        sound?.play()
    }

    private func injectBackspaces(count: Int) {
        let src = CGEventSource(stateID: .combinedSessionState)
        for i in 0..<count {
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0x33, keyDown: true) // 0x33 = delete/backspace
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0x33, keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
            if i < count - 1 {
                usleep(2_000) // 2ms between backspaces
            }
        }
    }

    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure the pasteboard server has propagated the new content
        // before the target app processes the Cmd+V. Without this, the first expansion
        // after a period of inactivity can paste stale clipboard contents.
        usleep(10_000) // 10ms

        // Inject Cmd+V
        let src = CGEventSource(stateID: .combinedSessionState)
        // keycode 9 = 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Restore clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            if let prev = previousContents {
                pasteboard.setString(prev, forType: .string)
            }
        }
    }
}
