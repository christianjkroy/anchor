import SwiftUI
import SwiftData

struct PersonDetailView: View {
    let person: Person
    @Environment(\.modelContext) private var modelContext
    @State private var showLogInteraction = false
    @State private var patterns: [Pattern] = []
    @State private var isDetectingPatterns = false
    @State private var patternError: String?

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

                // Patterns section
                if !patterns.isEmpty || person.interactions.count >= 4 {
                    PatternsSection(
                        patterns: patterns,
                        isLoading: isDetectingPatterns,
                        canDetect: person.interactions.count >= 4,
                        onDetect: { Task { await detectPatterns() } }
                    )
                    .padding()

                    Divider()
                }

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
        .onAppear {
            // Load any previously saved patterns for this person
            let name = person.name
            patterns = (try? modelContext.fetch(
                FetchDescriptor<Pattern>(predicate: #Predicate { $0.personName == name })
            )) ?? []
        }
        .alert("Pattern detection failed", isPresented: .constant(patternError != nil)) {
            Button("OK") { patternError = nil }
        } message: {
            Text(patternError ?? "")
        }
    }

    private func detectPatterns() async {
        isDetectingPatterns = true
        defer { isDetectingPatterns = false }
        do {
            let results = try await ClaudeService.shared.detectPatterns(for: person)
            // Delete old patterns for this person
            let name = person.name
            let old = (try? modelContext.fetch(
                FetchDescriptor<Pattern>(predicate: #Predicate { $0.personName == name })
            )) ?? []
            old.forEach { modelContext.delete($0) }

            patterns = results.map { r in
                let p = Pattern(patternType: r.type, summary: r.summary, detail: r.detail, severity: r.severity, personName: person.name)
                modelContext.insert(p)
                return p
            }
            try? modelContext.save()
            HapticFeedback.success()
        } catch {
            patternError = error.localizedDescription
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

// MARK: - Patterns Section

private struct PatternsSection: View {
    let patterns: [Pattern]
    let isLoading: Bool
    let canDetect: Bool
    let onDetect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Patterns")
                    .font(.headline)
                Spacer()
                Button {
                    onDetect()
                } label: {
                    if isLoading {
                        ProgressView().tint(AnchorColors.secure)
                    } else {
                        Label(patterns.isEmpty ? "Detect" : "Refresh", systemImage: "wand.and.stars")
                            .font(.caption)
                            .foregroundStyle(AnchorColors.secure)
                    }
                }
                .disabled(!canDetect || isLoading)
            }

            if patterns.isEmpty && !isLoading {
                Text(canDetect ? "Tap Detect to analyze your interaction history." : "Log at least 4 interactions to detect patterns.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(patterns) { pattern in
                    PersonPatternRow(pattern: pattern)
                }
            }
        }
    }
}

private struct PersonPatternRow: View {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: pattern.patternType.systemImage)
                    .font(.caption)
                    .foregroundStyle(severityColor)
                Text(pattern.summary)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(severityColor.opacity(0.25), lineWidth: 1))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expanded.toggle()
            }
        }
    }
}

#Preview {
    let container = PreviewData.container()
    let person = PreviewData.person(in: container)
    return NavigationStack {
        PersonDetailView(person: person)
    }
    .modelContainer(container)
}
