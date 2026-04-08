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
                    Button(action: { onSelect(option) }) {
                        VStack(spacing: 2) {
                            Text(option.label)
                                .font(.system(size: 13, weight: .semibold))
                            Text(option.sublabel)
                                .font(.system(size: 9))
                                .opacity(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(.primary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.primary.opacity(0.15), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }

            Text("Press \(keyHint) to respond · Esc dismisses (Claude still waiting)")
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

    private var keyHint: String {
        options.map { $0.label }.joined(separator: " · ")
    }
}
