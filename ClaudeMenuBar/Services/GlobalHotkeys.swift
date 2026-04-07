import CoreGraphics
import AppKit

final class GlobalHotkeys {
    private var eventTap: CFMachPort?
    var onKey: ((String) -> Void)?

    func enable() {
        guard AXIsProcessTrusted() else {
            requestAccessibility()
            return
        }
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let hotkeys = Unmanaged<GlobalHotkeys>.fromOpaque(refcon).takeUnretainedValue()
                return hotkeys.handle(event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap = eventTap else { return }
        let loop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), loop, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func disable() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        eventTap = nil
    }

    private func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let codeMap: [Int64: String] = [
            0x10: "y", 0x00: "a", 0x2D: "n",
            0x12: "1", 0x13: "2", 0x14: "3",
            0x35: "esc"
        ]
        guard let key = codeMap[keyCode] else { return Unmanaged.passRetained(event) }
        onKey?(key)
        return nil
    }

    private func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }
}
