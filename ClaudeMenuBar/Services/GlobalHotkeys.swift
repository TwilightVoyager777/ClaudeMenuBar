import AppKit
import Carbon
import CoreGraphics

final class GlobalHotkeys {
    var onKey: ((String) -> Void)?

    /// Whether bare-key interception is active (CGEventTap + local monitor).
    /// Carbon modifier hotkeys always fire but check this flag.
    private var isEnabled = false

    // CGEventTap + local monitor — dynamically enabled/disabled
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?

    // Carbon global hotkeys (⌃⇧Y/A/N) — registered once, always listening
    private var carbonHandlerRef: EventHandlerRef?
    private var carbonHotKeyRefs: [EventHotKeyRef?] = []

    private static let keyMap: [UInt16: String] = [
        0x10: "y",  // Y
        0x00: "a",  // A
        0x2D: "n",  // N
    ]

    init() {
        installCarbonHotKeys()
    }

    deinit {
        disable()
        removeCarbonHotKeys()
    }

    func enable() {
        isEnabled = true
        guard eventTap == nil, localMonitor == nil else { return }

        // CGEventTap — bare Y/A/N system-wide (blocked by Secure Input)
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: GlobalHotkeys.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        if let eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }

        // Local NSEvent monitor — bare Y/A/N when dropdown has focus
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isEnabled else { return event }
            if event.keyCode == 53 {
                self.onKey?("esc")
                return nil
            }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isBareLetter = mods.isEmpty || mods == .capsLock
            if isBareLetter, let key = Self.keyMap[event.keyCode] {
                self.onKey?(key)
                return nil
            }
            return event
        }
    }

    func disable() {
        isEnabled = false
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }

    // MARK: - Carbon global hotkeys (⌃⇧Y/A/N) — always registered

    private func installCarbonHotKeys() {
        guard carbonHandlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.carbonCallback,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &carbonHandlerRef
        )
        guard status == noErr else { return }

        let sig = OSType(0x434D4258) // "CMBX"
        let mods = UInt32(optionKey | cmdKey)
        let keys: [(UInt32, UInt32)] = [
            (UInt32(kVK_ANSI_Y), 1),
            (UInt32(kVK_ANSI_A), 2),
            (UInt32(kVK_ANSI_N), 3),
        ]
        for (keyCode, id) in keys {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(keyCode, mods, EventHotKeyID(signature: sig, id: id),
                                GetApplicationEventTarget(), 0, &ref)
            carbonHotKeyRefs.append(ref)
        }
    }

    private func removeCarbonHotKeys() {
        for ref in carbonHotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        carbonHotKeyRefs.removeAll()
        if let handler = carbonHandlerRef {
            RemoveEventHandler(handler)
            carbonHandlerRef = nil
        }
    }

    // Carbon callback — fires even from browsers; checks isEnabled flag
    private static let carbonCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }
        let hotkeys = Unmanaged<GlobalHotkeys>.fromOpaque(userData).takeUnretainedValue()
        guard hotkeys.isEnabled else { return OSStatus(eventNotHandledErr) }
        var hotKeyID = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject),
                          EventParamType(typeEventHotKeyID), nil,
                          MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        switch hotKeyID.id {
        case 1: hotkeys.onKey?("y")
        case 2: hotkeys.onKey?("a")
        case 3: hotkeys.onKey?("n")
        default: return OSStatus(eventNotHandledErr)
        }
        return noErr
    }

    // MARK: - CGEventTap callback (bare keys)

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let hotkeys = Unmanaged<GlobalHotkeys>.fromOpaque(refcon).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = hotkeys.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == 53 {
            hotkeys.onKey?("esc")
            return nil
        }

        let flags = event.flags
        let hasMods = flags.contains(.maskCommand)
            || flags.contains(.maskControl)
            || flags.contains(.maskAlternate)
        if !hasMods, let key = keyMap[keyCode] {
            hotkeys.onKey?(key)
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
