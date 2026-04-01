import SwiftUI

struct SentimentBadge: View {
    let label: SentimentLabel
    let confidence: Double
    var showConfidence: Bool = false

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(label.color)
                .frame(width: 6, height: 6)
            Text(label.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
            if showConfidence {
                Text("\(Int(confidence * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(label.color.opacity(0.12)))
        .foregroundStyle(label.color)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.85, anchor: .trailing)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}
