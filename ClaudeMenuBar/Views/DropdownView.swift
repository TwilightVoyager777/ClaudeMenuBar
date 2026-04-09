import AppKit
import SwiftUI

struct DropdownView: View {
    let message: String
    let options: [InputOption]
    let onSelect: (InputOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(options) { option in
                    OptionButton(option: option, onSelect: onSelect)
                }
            }

            Text("Press \(bareKeyHint) or ⌥⌘\(bareKeyHint) · Esc dismisses")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .frame(width: 240)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var bareKeyHint: String {
        options.map(\.label).joined(separator: " / ")
    }
}

/// Button that handles clicks at the AppKit level — works in non-key windows.
private struct OptionButton: View {
    let option: InputOption
    let onSelect: (InputOption) -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            Text(option.label)
                .font(.system(size: 13, weight: .semibold))
            Text(option.sublabel)
                .font(.system(size: 9))
                .opacity(0.6)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(.primary.opacity(isHovered ? 0.15 : 0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            AppKitTapArea(
                onHover: { isHovered = $0 },
                onTap: { onSelect(option) }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        )
    }
}

// MARK: - AppKit click handler (bypasses SwiftUI gesture system)

private struct AppKitTapArea: NSViewRepresentable {
    let onHover: (Bool) -> Void
    let onTap: () -> Void

    func makeNSView(context: Context) -> AppKitTapView {
        let v = AppKitTapView()
        v.onHover = onHover
        v.onTap = onTap
        return v
    }

    func updateNSView(_ nsView: AppKitTapView, context: Context) {
        nsView.onHover = onHover
        nsView.onTap = onTap
    }
}

final class AppKitTapView: NSView {
    var onHover: ((Bool) -> Void)?
    var onTap: (() -> Void)?
    private var tracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        if let t = tracking { removeTrackingArea(t) }
        tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(tracking!)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onTap?()
        }
    }
}
