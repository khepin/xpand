import Carbon
import CoreGraphics

enum KeyMapping {
    static func character(for keyCode: CGKeyCode, event: CGEvent) -> Character? {
        let maxLength = 4
        var chars = [UniChar](repeating: 0, count: maxLength)
        var length = 0
        var deadKeyState: UInt32 = 0

        guard let keyboard = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(keyboard, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let keyboardLayout = unsafeBitCast(
            CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self
        )

        let modifiers = event.flags
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.maskShift) { carbonModifiers |= UInt32(shiftKey >> 8) }
        if modifiers.contains(.maskCommand) { carbonModifiers |= UInt32(cmdKey >> 8) }
        if modifiers.contains(.maskAlternate) { carbonModifiers |= UInt32(optionKey >> 8) }
        if modifiers.contains(.maskControl) { carbonModifiers |= UInt32(controlKey >> 8) }

        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            carbonModifiers,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            maxLength,
            &length,
            &chars
        )

        guard status == noErr, length > 0 else { return nil }
        let str = String(utf16CodeUnits: chars, count: length)
        return str.first
    }
}
