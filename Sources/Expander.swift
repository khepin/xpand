import AppKit
import CoreGraphics

final class Expander {
    static let userData: Int64 = 0x7870_616E   // "xpan"

    private let engine: JSEngine
    private let sound: NSSound?
    private let source: CGEventSource

    init(engine: JSEngine, soundPath: String?) {
        self.engine = engine
        self.source = CGEventSource(stateID: .combinedSessionState)!
        self.source.userData = Self.userData
        if let path = soundPath {
            self.sound = NSSound(contentsOfFile: path, byReference: true)
        } else {
            self.sound = nil
        }
    }

    func expand(trigger: String) {
        guard let replacement = engine.expand(trigger: trigger) else { return }

        let deleteCount = trigger.count
        injectBackspaces(count: deleteCount)

        // Paste replacement via clipboard
        pasteText(replacement)

        // Play sound
        sound?.stop()
        sound?.play()
    }

    private func injectBackspaces(count: Int) {
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCount = pasteboard.changeCount

        // Small delay to ensure the pasteboard server has propagated the new content
        // before the target app processes the Cmd+V. Without this, the first expansion
        // after a period of inactivity can paste stale clipboard contents.
        usleep(10_000) // 10ms

        // Inject Cmd+V
        // keycode 9 = 'v'
        let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Restore clipboard after a delay, but only if no other process changed it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard pasteboard.changeCount == changeCount else { return }
            pasteboard.clearContents()
            if let prev = previousContents {
                pasteboard.setString(prev, forType: .string)
            }
        }
    }
}
