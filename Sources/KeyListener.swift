import CoreGraphics
import Foundation

final class KeyListener {
    private var triggers: [String]
    private var expander: Expander
    private var buffer: String = ""
    private var maxBufferLength: Int
    private var tap: CFMachPort?

    init(triggers: [String], expander: Expander) {
        self.triggers = triggers
        self.expander = expander
        self.maxBufferLength = triggers.map(\.count).max() ?? 32
    }

    func reload(triggers: [String], expander: Expander) {
        self.triggers = triggers
        self.expander = expander
        self.maxBufferLength = triggers.map(\.count).max() ?? 32
        self.buffer = ""
        print("xpand: reloaded (\(triggers.count) triggers loaded)")
    }

    func start() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)

        // Use an Unmanaged pointer to pass self into the C callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let listener = Unmanaged<KeyListener>.fromOpaque(refcon).takeUnretainedValue()
                return listener.handleEvent(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        self.tap = tap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("xpand: listening (\(triggers.count) triggers loaded)")
        CFRunLoopRun()
        return true
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable the tap if macOS disabled it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Ignore our own synthetic events
        if event.getIntegerValueField(.eventSourceUserData) == Expander.userData {
            return Unmanaged.passUnretained(event)
        }

        // Mouse clicks reset the buffer (cursor moved)
        if type == .leftMouseDown || type == .rightMouseDown {
            buffer = ""
            return Unmanaged.passUnretained(event)
        }

        let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Modifier combos (Cmd, Ctrl, Option) reset the buffer
        if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            buffer = ""
            return Unmanaged.passUnretained(event)
        }

        // Navigation / editing keys reset the buffer
        let resetKeycodes: Set<CGKeyCode> = [
            0x33, // delete (backspace)
            0x75, // forward delete
            0x24, // return
            0x4C, // keypad enter
            0x30, // tab
            0x35, // escape
            0x7B, 0x7C, 0x7D, 0x7E, // arrows: left, right, down, up
            0x73, // home
            0x77, // end
            0x74, // page up
            0x79, // page down
        ]
        if resetKeycodes.contains(keycode) {
            buffer = ""
            return Unmanaged.passUnretained(event)
        }

        guard let char = KeyMapping.character(for: keycode, event: event) else {
            return Unmanaged.passUnretained(event)
        }

        buffer.append(char)
        if buffer.count > maxBufferLength {
            buffer.removeFirst(buffer.count - maxBufferLength)
        }

        for trigger in triggers {
            if buffer.hasSuffix(trigger) {
                buffer = ""
                DispatchQueue.main.async {
                    self.expander.expand(trigger: trigger)
                }
                return Unmanaged.passUnretained(event)
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
