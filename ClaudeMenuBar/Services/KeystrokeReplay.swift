import CoreGraphics
import AppKit

enum KeystrokeReplay {
    /// Posts a key character to the system (simulates typing in active window)
    static func type(_ character: String) {
        guard let keyCode = keyCode(for: character) else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // Follow with Return
        let returnDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        let returnUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
        returnDown?.post(tap: .cghidEventTap)
        returnUp?.post(tap: .cghidEventTap)
    }

    private static func keyCode(for character: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            "y": 0x10, "Y": 0x10,
            "a": 0x00, "A": 0x00,
            "n": 0x2D, "N": 0x2D,
            "1": 0x12, "2": 0x13, "3": 0x14,
        ]
        return map[character]
    }
}
