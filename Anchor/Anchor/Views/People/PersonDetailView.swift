import SwiftUI

struct PersonDetailView: View {
    let person: Person
    @State private var showLogInteraction = false

    private var sortedInteractions: [Interaction] {
        person.interactions.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                PersonHeaderView(person: person)
                    .padding()

                Divider()

                // Stats bar
                StatsBarView(person: person)
                    .padding()

                Divider()

                // Interactions list
                if sortedInteractions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No interactions yet")
                            .foregroundStyle(.secondary)
                        Text("Tap below to log your first one")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    VStack(spacing: 0) {
                        ForEach(sortedInteractions) { interaction in
                            InteractionRowView(interaction: interaction)
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showLogInteraction = true
            } label: {
                Label("Log Interaction", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AnchorColors.secure)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showLogInteraction) {
            LogInteractionView(person: person)
        }
    }
}

// MARK: - Header

private struct PersonHeaderView: View {
    let person: Person

    var body: some View {
        HStack(spacing: 16) {
            AvatarView(person: person, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                RelationshipPill(type: person.relationshipType)
                Text("Added \(person.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Stats Bar

private struct StatsBarView: View {
    let person: Person

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                StatCell(label: "Interactions", value: "\(person.totalInteractions)")

                if let days = person.daysSinceLastInteraction {
                    StatCell(label: "Last seen", value: days == 0 ? "Today" : "\(days)d ago")
                }

                if let feeling = person.mostCommonFeelingAfter {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usually feel after")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(feeling.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(feeling.color.opacity(0.18)))
                            .foregroundStyle(feeling.color)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Initiation")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                InitiationRatioBar(ratio: person.initiationRatio, height: 8)
            }

            let dist = person.sentimentDistribution
            SentimentDistributionBar(
                anxious: dist.anxious,
                secure: dist.secure,
                avoidant: dist.avoidant
            )
        }
    }
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Interaction Row

struct InteractionRowView: View {
    let interaction: Interaction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: interaction.interactionType.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(interaction.interactionType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(interaction.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let label = interaction.sentimentLabel, let confidence = interaction.sentimentConfidence {
                    SentimentBadge(label: label, confidence: confidence)
                }
            }

            // Feelings row
            HStack(spacing: 6) {
                FeelPill(label: interaction.feelingBefore.rawValue, color: interaction.feelingBefore.color)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
                FeelPill(label: interaction.feelingDuring.rawValue, color: interaction.feelingDuring.color)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
                FeelPill(label: interaction.feelingAfter.rawValue, color: interaction.feelingAfter.color)
            }

            // Initiator
            HStack(spacing: 4) {
                Text("Initiated by:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(interaction.initiator.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            // Note
            if !interaction.note.isEmpty {
                Text(interaction.note)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct FeelPill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}
