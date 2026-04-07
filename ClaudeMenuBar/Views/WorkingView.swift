import SwiftUI

struct WorkingView: View {
    let tool: String
    let detail: String

    var body: some View {
        HStack(spacing: 7) {
            BreathingDot(hexColor: "#7c3aed")
            Text("\(tool) · \(detail)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "#a78bfa"))
                .lineLimit(1)
            BouncingEllipsis()
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .background(
            Capsule()
                .fill(Color(hex: "#13111f"))
                .overlay(Capsule().strokeBorder(Color(hex: "#7c3aed").opacity(0.3), lineWidth: 1))
        )
    }
}

struct CompleteView: View {
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(hex: "#22c55e"))
                .frame(width: 6, height: 6)
                .shadow(color: Color(hex: "#22c55e"), radius: 4)
            Text("任务完成")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "#86efac"))
        }
        .padding(.horizontal, 14)
        .frame(height: 22)
        .background(
            Capsule()
                .fill(Color(hex: "#052e16"))
                .overlay(Capsule().strokeBorder(Color(hex: "#22c55e").opacity(0.3), lineWidth: 1))
        )
    }
}

// MARK: - Sub-components

struct BreathingDot: View {
    let hexColor: String
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(Color(hex: hexColor))
            .frame(width: 6, height: 6)
            .shadow(color: Color(hex: hexColor), radius: 3)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 0.5
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
                    .fill(Color(hex: "#7c3aed").opacity(0.6))
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
