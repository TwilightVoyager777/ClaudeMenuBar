import SwiftUI

struct WorkingView: View {
    let tool: String
    let detail: String

    var body: some View {
        HStack(spacing: 5) {
            BreathingDot()
            Text(tool)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            BouncingEllipsis()
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
    }
}

struct CompleteView: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
            Text("完成")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Sub-components

struct BreathingDot: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(.primary)
            .frame(width: 5, height: 5)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 0.4
                }
            }
    }
}

struct BouncingEllipsis: View {
    @State private var offsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.primary.opacity(0.5))
                    .frame(width: 3, height: 3)
                    .offset(y: offsets[i])
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2)
                        ) {
                            offsets[i] = -2
                        }
                    }
            }
        }
    }
}
