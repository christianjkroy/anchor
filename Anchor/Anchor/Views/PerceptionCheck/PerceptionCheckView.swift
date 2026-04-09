import SwiftUI
import SwiftData

// MARK: - Perception Check Entry Point

struct PerceptionCheckView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]

    @State private var selectedPerson: Person?
    @State private var perceivedScore: Int = 3
    @State private var result: PerceptionResult?
    @State private var isChecking = false
    @State private var history: [PerceptionResult] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard

                    personPicker

                    if selectedPerson != nil {
                        scoreSelector
                        checkButton
                    }

                    if let result {
                        resultCard(result)
                    }

                    if !history.isEmpty {
                        historySection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Perception Check")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: selectedPerson) { _, person in
                result = nil
                if let person { loadHistory(for: person) }
            }
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reality Check", systemImage: "brain.head.profile")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AnchorColors.secure)

            Text("Start with your gut, then compare it against the interaction history you’ve actually logged.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [AnchorColors.secure.opacity(0.12), AnchorColors.neutral.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AnchorColors.secure.opacity(0.18), lineWidth: 1))
        )
    }

    private var personPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Who are you checking in on?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Pick one person and rate the relationship as it feels to you right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(people) { person in
                        Button {
                            selectedPerson = person
                        } label: {
                            Text(person.name)
                                .font(.subheadline)
                                .fontWeight(selectedPerson?.id == person.id ? .semibold : .regular)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        selectedPerson?.id == person.id
                                        ? AnchorColors.secure
                                        : Color(.systemGray5)
                                    )
                                )
                                .foregroundStyle(selectedPerson?.id == person.id ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }

            if people.isEmpty {
                Text("Add people first to run a perception check.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var scoreSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("How does this relationship feel right now?")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("1 means shaky and uneasy. 5 means grounded and strong.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                Text("Uncertain")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Confident")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { score in
                    Button {
                        perceivedScore = score
                        HapticFeedback.light()
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(scoreColor(score))
                                    .frame(width: 46, height: 46)
                                Text("\(score)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            .scaleEffect(perceivedScore == score ? 1.15 : 1.0)
                            .shadow(color: scoreColor(score).opacity(perceivedScore == score ? 0.4 : 0), radius: 6)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: perceivedScore)

                            Text(scoreLabel(score))
                                .font(.caption2)
                                .foregroundStyle(perceivedScore == score ? .primary : .secondary)
                        }
                    }
                    if score < 5 { Spacer() }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var checkButton: some View {
        Button {
            Task { await runCheck() }
        } label: {
            if isChecking {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [AnchorColors.secure, AnchorColors.neutral],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Label("Run Perception Check", systemImage: "magnifyingglass")
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
            }
        }
        .disabled(isChecking || selectedPerson == nil)
    }

    private func resultCard(_ r: PerceptionResult) -> some View {
        let divergence = abs(r.perceivedScore - r.realityScore)
        let flagged = divergence > 1.5
        let direction = r.perceivedScore < r.realityScore ? "underestimating" : "overestimating"

        return VStack(alignment: .leading, spacing: 16) {
            // Scores side by side
            HStack(spacing: 0) {
                ScoreCell(label: "You feel", score: r.perceivedScore, color: scoreColor(Int(r.perceivedScore.rounded())))
                Divider().frame(height: 60)
                ScoreCell(label: "Data says", score: r.realityScore, color: AnchorColors.secure)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Divergence badge
            if flagged {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AnchorColors.anxious)
                    Text("You're \(direction) this relationship by \(String(format: "%.1f", divergence)) points.")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(AnchorColors.anxious.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AnchorColors.secure)
                    Text("Your gut feeling is reasonably aligned with the data.")
                        .font(.subheadline)
                }
                .padding(12)
                .background(AnchorColors.secure.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Data basis
            if !r.basisNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Based on")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                    ForEach(r.basisNotes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 6) {
                            Text("·").foregroundStyle(.secondary)
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Checks")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(history.prefix(5)) { check in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("You: \(String(format: "%.0f", check.perceivedScore))  ·  Data: \(String(format: "%.1f", check.realityScore))")
                            .font(.caption)
                    }
                    Spacer()
                    let div = abs(check.perceivedScore - check.realityScore)
                    Text(div > 1.5 ? "Flagged" : "Aligned")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(div > 1.5 ? AnchorColors.anxious.opacity(0.12) : AnchorColors.secure.opacity(0.12)))
                        .foregroundStyle(div > 1.5 ? AnchorColors.anxious : AnchorColors.secure)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Logic

    private func runCheck() async {
        guard let person = selectedPerson else { return }
        isChecking = true
        defer { isChecking = false }

        HapticFeedback.medium()
        let check = PerceptionResult.compute(for: person, perceivedScore: Double(perceivedScore))
        result = check

        // Persist to SwiftData
        let saved = PerceptionCheck(
            personName: person.name,
            perceivedScore: Double(perceivedScore),
            realityScore: check.realityScore,
            divergence: abs(Double(perceivedScore) - check.realityScore),
            flagged: abs(Double(perceivedScore) - check.realityScore) > 1.5
        )
        modelContext.insert(saved)
        try? modelContext.save()

        // Refresh history
        loadHistory(for: person)
        HapticFeedback.success()
    }

    private func loadHistory(for person: Person) {
        let name = person.name
        let fetched = (try? modelContext.fetch(
            FetchDescriptor<PerceptionCheck>(
                predicate: #Predicate { $0.personName == name },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        )) ?? []
        history = fetched.map { PerceptionResult(
            perceivedScore: $0.perceivedScore,
            realityScore: $0.realityScore,
            basisNotes: [],
            date: $0.date
        )}
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 1: return AnchorColors.anxious
        case 2: return Color(red: 0.88, green: 0.64, blue: 0.55)
        case 3: return AnchorColors.neutral
        case 4: return Color(red: 0.47, green: 0.72, blue: 0.68)
        case 5: return AnchorColors.secure
        default: return .secondary
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        ["Very\nuneasy", "Uneasy", "Unsure", "OK", "Great"][score - 1]
    }
}

// MARK: - Score Cell

private struct ScoreCell: View {
    let label: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", score))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Data Types

struct PerceptionResult: Identifiable {
    let id = UUID()
    let perceivedScore: Double
    let realityScore: Double
    let basisNotes: [String]
    var date: Date = .now

    static func compute(for person: Person, perceivedScore: Double) -> PerceptionResult {
        let interactions = person.interactions
        guard !interactions.isEmpty else {
            return PerceptionResult(perceivedScore: perceivedScore, realityScore: 2.5, basisNotes: ["No interaction data yet."])
        }

        // They-initiation ratio → maps 0…1 to 1…5
        let meaningful = interactions.filter { $0.initiator != .unclear }
        let theyRatio = meaningful.isEmpty ? 0.5 :
            Double(meaningful.filter { $0.initiator == .them }.count) / Double(meaningful.count)

        // Secure interaction fraction → maps 0…1 to 1…5
        let labeled = interactions.compactMap(\.sentimentLabel)
        let secureFrac = labeled.isEmpty ? 0.5 :
            Double(labeled.filter { $0 == .secure }.count) / Double(labeled.count)

        // Weighted composite on 1–5 scale
        let rawReality = theyRatio * 2.0 + secureFrac * 3.0
        let realityScore = min(5.0, max(1.0, rawReality))

        var notes: [String] = []
        notes.append("\(Int(theyRatio * 100))% of interactions initiated by them (\(meaningful.count) tracked)")
        if !labeled.isEmpty {
            notes.append("\(Int(secureFrac * 100))% of interactions felt secure (\(labeled.count) labeled)")
        }
        notes.append("\(interactions.count) total interaction\(interactions.count == 1 ? "" : "s") logged")

        return PerceptionResult(perceivedScore: perceivedScore, realityScore: realityScore, basisNotes: notes)
    }
}

// MARK: - SwiftData model for persistence

@Model
final class PerceptionCheck {
    var personName: String
    var perceivedScore: Double
    var realityScore: Double
    var divergence: Double
    var flagged: Bool
    var date: Date

    init(personName: String, perceivedScore: Double, realityScore: Double, divergence: Double, flagged: Bool, date: Date = .now) {
        self.personName = personName
        self.perceivedScore = perceivedScore
        self.realityScore = realityScore
        self.divergence = divergence
        self.flagged = flagged
        self.date = date
    }
}

#Preview {
    PerceptionCheckView()
        .modelContainer(PreviewData.container())
}
