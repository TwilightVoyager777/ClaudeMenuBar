import SwiftUI

struct DropdownView: View {
    let message: String
    let options: [InputOption]
    let onSelect: (InputOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Color(.labelColor))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(options) { option in
                    Button(action: { onSelect(option) }) {
                        VStack(spacing: 2) {
                            Text(option.label)
                                .font(.system(size: 12, weight: .bold))
                            Text(option.sublabel)
                                .font(.system(size: 8))
                                .opacity(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(optionBackground(for: option))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(optionBorder(for: option), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(optionForeground(for: option))
                }
            }

            Text("按键盘 \(keyHint) 直接响应")
                .font(.system(size: 8))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .frame(width: 240)
        .background(Color(hex: "#120c00"))
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 14,
                bottomTrailingRadius: 14, topTrailingRadius: 0
            )
            .strokeBorder(Color(hex: "#f59e0b").opacity(0.3), lineWidth: 1)
        )
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 14,
            bottomTrailingRadius: 14, topTrailingRadius: 0
        ))
    }

    private var keyHint: String {
        options.map { $0.label }.joined(separator: " · ")
    }

    private func optionBackground(for option: InputOption) -> Color {
        switch option.id {
        case "y", "1": return Color(hex: "#14532d")
        case "a": return Color(hex: "#1e3a5f")
        case "n": return Color(hex: "#450a0a")
        default:  return Color(hex: "#1a1a2e")
        }
    }

    private func optionBorder(for option: InputOption) -> Color {
        switch option.id {
        case "y", "1": return Color(hex: "#16a34a").opacity(0.4)
        case "a": return Color(hex: "#2563eb").opacity(0.4)
        case "n": return Color(hex: "#dc2626").opacity(0.4)
        default:  return Color(hex: "#7c3aed").opacity(0.3)
        }
    }

    private func optionForeground(for option: InputOption) -> Color {
        switch option.id {
        case "y", "1": return Color(hex: "#86efac")
        case "a": return Color(hex: "#93c5fd")
        case "n": return Color(hex: "#fca5a5")
        default:  return Color(hex: "#c4b5fd")
        }
    }
}
