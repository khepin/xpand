import CoreGraphics
import Foundation

final class KeyListener {
    private let triggers: [String]
    private let expander: Expander
    private var buffer: String = ""
    private let maxBufferLength: Int

    init(triggers: [String], expander: Expander) {
        self.triggers = triggers
        self.expander = expander
        self.maxBufferLength = triggers.map(\.count).max() ?? 32
    }

    func start() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Use an Unmanaged pointer to pass self into the C callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let listener = Unmanaged<KeyListener>.fromOpaque(refcon).takeUnretainedValue()
                return listener.handleEvent(event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("xpand: listening (\(triggers.count) triggers loaded)")
        CFRunLoopRun()
        return true
    }

    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let char = KeyMapping.character(for: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)), event: event) else {
            return Unmanaged.passUnretained(event)
        }

        buffer.append(char)
        if buffer.count > maxBufferLength {
            buffer.removeFirst(buffer.count - maxBufferLength)
        }

        for trigger in triggers {
            if buffer.hasSuffix(trigger) {
                buffer = ""
                // Suppress this last keystroke and expand
                DispatchQueue.main.async {
                    self.expander.expand(trigger: trigger)
                }
                return nil // swallow the event
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
