import SwiftUI

struct DigestDetailView: View {
    let digest: WeeklyDigest
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Narrative
                VStack(alignment: .leading, spacing: 8) {
                    Label("This Week", systemImage: "text.bubble")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(digest.narrativeParagraph)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // Patterns
                if !digest.patterns.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Patterns Detected")
                            .font(.headline)

                        ForEach(digest.patterns.sorted { $0.severityRaw > $1.severityRaw }) { pattern in
                            PatternCard(pattern: pattern)
                        }
                    }
                }

                // Initiation changes
                let changes = digest.initiationChanges
                if !changes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Initiation Shifts")
                            .font(.headline)

                        ForEach(changes, id: \.personName) { change in
                            InitiationChangeRow(change: change)
                        }
                    }
                }

                Text("Generated \(digest.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom)
            }
            .padding()
        }
        .navigationTitle(digest.weekDateRangeString)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !digest.isRead {
                digest.isRead = true
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Pattern Card

private struct PatternCard: View {
    let pattern: Pattern
    @State private var expanded = false

    var severityColor: Color {
        switch pattern.severity {
        case .high:   return AnchorColors.anxious
        case .medium: return Color(red: 0.88, green: 0.78, blue: 0.55)
        case .low:    return AnchorColors.secure
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: pattern.patternType.systemImage)
                    .foregroundStyle(severityColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.patternType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pattern.summary)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                Text(pattern.severity.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(severityColor.opacity(0.15)))
                    .foregroundStyle(severityColor)

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if expanded {
                Text(pattern.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(severityColor.opacity(0.3), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expanded.toggle()
            }
        }
    }
}

// MARK: - Initiation Change Row

private struct InitiationChangeRow: View {
    let change: InitiationChange

    var arrowImage: String {
        if change.delta > 0.05 { return "arrow.up.circle.fill" }
        if change.delta < -0.05 { return "arrow.down.circle.fill" }
        return "minus.circle.fill"
    }

    var arrowColor: Color {
        if change.delta > 0.05 { return AnchorColors.anxious }
        if change.delta < -0.05 { return AnchorColors.secure }
        return AnchorColors.avoidant
    }

    var body: some View {
        HStack {
            Text(change.personName)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Text("\(Int(change.previousRatio * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: arrowImage)
                .foregroundStyle(arrowColor)

            Text("\(Int(change.currentRatio * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
