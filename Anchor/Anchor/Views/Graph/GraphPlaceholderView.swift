import SwiftUI
import SwiftData

struct GraphPlaceholderView: View {
    @Query private var people: [Person]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)

                VStack(spacing: 20) {
                    ZStack {
                        ForEach(Array(people.prefix(5).enumerated()), id: \.offset) { index, person in
                            Circle()
                                .fill(person.dominantSentiment?.color ?? person.relationshipType.color)
                                .frame(width: nodeSize(for: person), height: nodeSize(for: person))
                                .offset(nodeOffset(index: index, total: min(people.count, 5)))
                                .opacity(0.7)
                        }

                        if people.isEmpty {
                            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                .font(.system(size: 60))
                                .foregroundStyle(AnchorColors.secure.opacity(0.4))
                        }
                    }
                    .frame(width: 220, height: 220)

                    VStack(spacing: 8) {
                        Text("Relationship Graph")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Coming in Phase 3 — a GPU-rendered force-directed map of your social world.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .navigationTitle("Graph")
        }
    }

    private func nodeSize(for person: Person) -> CGFloat {
        let base: CGFloat = 32
        let scale = min(CGFloat(person.totalInteractions) * 4, 40)
        return base + scale
    }

    private func nodeOffset(index: Int, total: Int) -> CGSize {
        guard total > 0 else { return .zero }
        let angle = (2 * Double.pi / Double(total)) * Double(index) - Double.pi / 2
        let radius: Double = 70
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}
