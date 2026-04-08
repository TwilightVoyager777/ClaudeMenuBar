import CoreGraphics
import AppKit

final class GlobalHotkeys {
    var onKey: ((String) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Public

    func enable() {
        // Idempotent: do nothing if a tap is already installed.
        guard eventTap == nil else { return }

        guard AXIsProcessTrusted() else {
            requestAccessibility()
            return
        }

        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                return Unmanaged<GlobalHotkeys>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()
                    .handle(event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    func disable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)   // releases the mach port
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Private

    private func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let map: [Int64: String] = [
            0x10: "y", 0x00: "a", 0x2D: "n",
            0x12: "1", 0x13: "2", 0x14: "3",
            0x35: "esc"
        ]
        guard let key = map[keyCode] else { return Unmanaged.passRetained(event) }
        onKey?(key)
        return nil  // consume the event
    }

    private func requestAccessibility() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(opts)
    }
}
