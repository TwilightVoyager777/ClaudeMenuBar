import SwiftUI

/// Compact anchor shown in the menu bar when waiting for input (top of pill, open bottom)
struct WaitingAnchorView: View {
    var body: some View {
        HStack(spacing: 7) {
            BreathingDot(hexColor: "#f59e0b")
            Text("需要你的确认")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(hex: "#fbbf24"))
        }
        .padding(.horizontal, 14)
        .frame(height: 22)
        .background(
            Color(hex: "#120c00")
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Color(hex: "#f59e0b").opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 11))
        )
    }
}
