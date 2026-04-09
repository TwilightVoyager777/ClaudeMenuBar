import AppKit

final class GlobalHotkeys {
    var onKey: ((String) -> Void)?

    private var localMonitor: Any?
    private var globalMonitor: Any?

    private let keyMap: [UInt16: String] = [
        0x10: "y",  // Y
        0x00: "a",  // A
        0x2D: "n",  // N
    ]

    private let globalModifiers: NSEvent.ModifierFlags = [.control, .option, .command]

    func enable() {
        guard localMonitor == nil else { return }

        // Local: works when dropdown is key — bare Y/A/N keys (no modifiers)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Esc dismisses
            if event.keyCode == 53 {
                self.onKey?("esc")
                return nil
            }

            // Bare Y/A/N (no modifiers) or ⌃⌥⌘Y/A/N
            let isBareLetter = mods.isEmpty || mods == .capsLock
            let isGlobalCombo = mods.contains(self.globalModifiers)
            if isBareLetter || isGlobalCombo,
               let key = self.keyMap[event.keyCode] {
                self.onKey?(key)
                return nil
            }
            return event
        }

        // Global: works from other apps — bare Y/A/N or ⌃⌥⌘Y/A/N (needs Accessibility)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isBareLetter = mods.isEmpty || mods == .capsLock
            let isGlobalCombo = mods.contains(self.globalModifiers)
            guard isBareLetter || isGlobalCombo,
                  let key = self.keyMap[event.keyCode] else { return }
            self.onKey?(key)
        }
    }

    func disable() {
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
    }
}
