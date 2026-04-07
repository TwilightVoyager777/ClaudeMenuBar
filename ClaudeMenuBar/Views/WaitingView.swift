import SwiftUI

/// Compact anchor shown in the menu bar when waiting for input
struct WaitingAnchorView: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "ellipsis.bubble")
                .font(.system(size: 11, weight: .medium))
            Text("需要确认")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
    }
}
