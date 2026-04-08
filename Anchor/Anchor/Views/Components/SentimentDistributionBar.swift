import SwiftUI

struct SentimentDistributionBar: View {
    let anxious: Double
    let secure: Double
    let avoidant: Double
    var height: CGFloat = 10

    private var hasData: Bool { anxious + secure + avoidant > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sentiment")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if hasData {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        if secure > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AnchorColors.secure)
                                .frame(width: geo.size.width * secure)
                        }
                        if anxious > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AnchorColors.anxious)
                                .frame(width: geo.size.width * anxious)
                        }
                        if avoidant > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AnchorColors.avoidant)
                                .frame(width: geo.size.width * avoidant)
                        }
                    }
                }
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                HStack(spacing: 12) {
                    LegendDot(color: AnchorColors.secure, label: "Secure", value: secure)
                    LegendDot(color: AnchorColors.anxious, label: "Anxious", value: anxious)
                    LegendDot(color: AnchorColors.avoidant, label: "Avoidant", value: avoidant)
                }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: height)
                Text("Log interactions with notes to see sentiment")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(Int(value * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("With data") {
    SentimentDistributionBar(anxious: 0.4, secure: 0.45, avoidant: 0.15)
        .padding()
}
#Preview("No data") {
    SentimentDistributionBar(anxious: 0, secure: 0, avoidant: 0)
        .padding()
}
