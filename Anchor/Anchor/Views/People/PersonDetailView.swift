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
            VStack(alignment: .leading, spacing: 18) {
                PersonHeaderView(person: person)
                StatsBarView(person: person)

                if !patterns.isEmpty || person.interactions.count >= 4 {
                    PatternsSection(
                        patterns: patterns,
                        isLoading: isDetectingPatterns,
                        canDetect: person.interactions.count >= 4,
                        onDetect: { Task { await detectPatterns() } }
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Interaction Timeline")
                            .font(.headline)
                        Spacer()
                        Text("\(sortedInteractions.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AnchorColors.secure.opacity(0.12)))
                            .foregroundStyle(AnchorColors.secure)
                    }

                    if sortedInteractions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("No interactions yet")
                                .font(.headline)
                            Text("Log the first interaction to start building a clearer picture of this relationship.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(sortedInteractions) { interaction in
                                InteractionRowView(interaction: interaction)
                            }
                        }
                    }
                }
                .detailSectionCard()
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            Button {
                showLogInteraction = true
            } label: {
                Label("Log Interaction", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [AnchorColors.secure, AnchorColors.neutral],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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
            let results = try await LocalAnalysisService.shared.detectPatterns(for: person)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                AvatarView(person: person, size: 68)

                VStack(alignment: .leading, spacing: 6) {
                    RelationshipPill(type: person.relationshipType)
                    Text(person.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(summaryLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                headerBadge(title: "Added", value: person.dateAdded.formatted(date: .abbreviated, time: .omitted))
                if let days = person.daysSinceLastInteraction {
                    headerBadge(title: "Last seen", value: days == 0 ? "Today" : "\(days)d ago")
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(.secondarySystemGroupedBackground), AnchorColors.secure.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var summaryLine: String {
        if let sentiment = person.dominantSentiment {
            return "Mostly \(sentiment.rawValue.lowercased()) interactions across \(person.totalInteractions) logged moments."
        }
        return "\(person.totalInteractions) logged interaction\(person.totalInteractions == 1 ? "" : "s") so far."
    }

    private func headerBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stats Bar

private struct StatsBarView: View {
    let person: Person

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                StatCell(label: "Interactions", value: "\(person.totalInteractions)")

                if let days = person.daysSinceLastInteraction {
                    StatCell(label: "Last seen", value: days == 0 ? "Today" : "\(days)d ago")
                }

                if let feeling = person.mostCommonFeelingAfterText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usually feel after")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(feeling)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AnchorColors.neutral.opacity(0.18)))
                            .foregroundStyle(AnchorColors.neutral)
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
        .detailSectionCard()
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
                FeelPill(label: interaction.displayFeelingBefore, color: interaction.feelingBefore.color)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
                FeelPill(label: interaction.displayFeelingDuring, color: interaction.feelingDuring.color)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
                FeelPill(label: interaction.displayFeelingAfter, color: interaction.feelingAfter.color)
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Patterns")
                        .font(.headline)
                    Text("Signals pulled from repeated interaction history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if canDetect {
                    Button {
                        onDetect()
                    } label: {
                        if isLoading {
                            ProgressView().tint(AnchorColors.secure)
                        } else {
                            Label(patterns.isEmpty ? "Analyze" : "Refresh", systemImage: "wand.and.stars")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(AnchorColors.secure.opacity(0.12)))
                                .foregroundStyle(AnchorColors.secure)
                        }
                    }
                    .disabled(isLoading)
                }
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
        .detailSectionCard()
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

private extension View {
    func detailSectionCard() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
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
