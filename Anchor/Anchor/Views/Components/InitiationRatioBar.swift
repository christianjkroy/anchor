import SwiftUI

struct InitiationRatioBar: View {
    let ratio: Double   // 0.0 = all them, 1.0 = all you
    var height: CGFloat = 6
    var showLabels: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabels {
                HStack {
                    Text("Them")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("You")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color(.systemGray5))
                        .frame(height: height)

                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(ratioColor)
                        .frame(width: max(height, geo.size.width * ratio), height: height)
                }
            }
            .frame(height: height)

            if showLabels {
                HStack {
                    Spacer()
                    Text("\(Int(ratio * 100))% you")
                        .font(.caption2)
                        .foregroundStyle(ratioColor)
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var ratioColor: Color {
        switch ratio {
        case ..<0.35: return AnchorColors.secure    // they initiate more — secure
        case 0.35..<0.65: return AnchorColors.neutral  // balanced
        default: return AnchorColors.anxious         // you initiate most — potential concern
        }
    }
}

#Preview("Balanced") { InitiationRatioBar(ratio: 0.5).padding() }
#Preview("You initiate most") { InitiationRatioBar(ratio: 0.8).padding() }
#Preview("They initiate most") { InitiationRatioBar(ratio: 0.2).padding() }
