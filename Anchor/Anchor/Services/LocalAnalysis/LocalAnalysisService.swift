import Foundation
import SwiftData
import FoundationModels

/// Sentiment and pattern analysis runs on-device using rule-based logic.
/// Digest narrative uses Apple Foundation Models (iOS 26+) with a template fallback.
actor LocalAnalysisService {
    static let shared = LocalAnalysisService()

    // MARK: - Sentiment Classification

    func classifySentiment(for interaction: Interaction) async throws -> (SentimentLabel, Double) {
        return Self.deriveSentiment(
            before: interaction.feelingBefore,
            during: interaction.feelingDuring,
            after: interaction.feelingAfter
        )
    }

    func classifyPendingSentiments(for person: Person, context: ModelContext) async throws {
        let unlabeled = person.interactions.filter { $0.sentimentLabel == nil }
        for interaction in unlabeled {
            let (label, confidence) = Self.deriveSentiment(
                before: interaction.feelingBefore,
                during: interaction.feelingDuring,
                after: interaction.feelingAfter
            )
            interaction.sentimentLabel = label
            interaction.sentimentConfidence = confidence
        }
        try? context.save()
    }

    // MARK: - Pattern Detection

    func detectPatterns(for person: Person) async throws -> [PatternResult] {
        guard person.interactions.count >= 4 else { return [] }
        var results: [PatternResult] = []
        if let p = Self.checkInitiationImbalance(person) { results.append(p) }
        if let p = Self.checkSentimentDrift(person)      { results.append(p) }
        if let p = Self.checkContextBehavior(person)     { results.append(p) }
        if let p = Self.checkPerceptionMismatch(person)  { results.append(p) }
        return results
    }

    // MARK: - Weekly Digest

    func generateWeeklyDigest(people: [Person]) async throws -> DigestResult {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let sixtyDaysAgo  = Calendar.current.date(byAdding: .day, value: -60, to: now)!

        let active = people.filter {
            !$0.interactions.filter { $0.timestamp >= thirtyDaysAgo }.isEmpty
        }
        guard !active.isEmpty else { throw AIError.insufficientData }

        var allPatterns: [PatternResult] = []
        for person in active {
            allPatterns.append(contentsOf: try await detectPatterns(for: person))
        }
        let topPatterns = Array(allPatterns.sorted { $0.severityRank > $1.severityRank }.prefix(3))

        let initiationChanges: [InitiationChange] = active.compactMap { person in
            let recent = person.interactions.filter { $0.timestamp >= thirtyDaysAgo }
            let prev   = person.interactions.filter { $0.timestamp >= sixtyDaysAgo && $0.timestamp < thirtyDaysAgo }
            guard !recent.isEmpty else { return nil }
            func ratio(_ list: [Interaction]) -> Double {
                let m = list.filter { $0.initiator != .unclear }
                guard !m.isEmpty else { return 0.5 }
                return Double(m.filter { $0.initiator == .you }.count) / Double(m.count)
            }
            return InitiationChange(personName: person.name, previousRatio: prev.isEmpty ? ratio(recent) : ratio(prev), currentRatio: ratio(recent))
        }
        .sorted { abs($0.delta) > abs($1.delta) }
        .prefix(5).map { $0 }

        let narrative = await Self.buildNarrative(people: active, thirtyDaysAgo: thirtyDaysAgo, now: now, patterns: topPatterns, initiationChanges: initiationChanges)

        return DigestResult(narrative: narrative, patterns: topPatterns, initiationChanges: initiationChanges)
    }

    // MARK: - Core: Sentiment Derivation

    static func deriveSentiment(
        before: FeelingBefore,
        during: FeelingDuring,
        after: FeelingAfter
    ) -> (SentimentLabel, Double) {
        var anxious = 0, secure = 0, avoidant = 0

        switch before {
        case .anxious:  anxious  += 1
        case .avoidant: avoidant += 1
        case .excited:  secure   += 1
        case .neutral:  break
        }

        switch during {
        case .connected, .secure, .authentic: secure   += 2
        case .anxious:                        anxious  += 2
        case .disconnected, .performative:    avoidant += 2
        }

        switch after {
        case .energized, .satisfied: secure   += 3
        case .calm:                  secure   += 2
        case .anxious, .regretful:   anxious  += 3
        case .drained:               avoidant += 3
        }

        let total = Double(anxious + secure + avoidant)
        let label: SentimentLabel
        let winnerScore: Int

        if secure >= anxious && secure >= avoidant {
            label = .secure;   winnerScore = secure
        } else if anxious >= avoidant {
            label = .anxious;  winnerScore = anxious
        } else {
            label = .avoidant; winnerScore = avoidant
        }

        let confidence = total > 0 ? min(0.95, max(0.5, Double(winnerScore) / total)) : 0.6
        return (label, confidence)
    }

    // MARK: - Core: Pattern Rules

    private static func checkInitiationImbalance(_ person: Person) -> PatternResult? {
        let meaningful = person.interactions.filter { $0.initiator != .unclear }
        guard meaningful.count >= 4 else { return nil }
        let youRatio = Double(meaningful.filter { $0.initiator == .you }.count) / Double(meaningful.count)
        if youRatio > 0.70 {
            let pct = Int(youRatio * 100)
            return PatternResult(type: .initiationImbalance, summary: "You initiate \(pct)% of contact", detail: "You've started \(pct)% of your interactions with \(person.name). This level of imbalance can feel exhausting over time and may be worth noticing.", severity: youRatio > 0.85 ? .high : .medium)
        } else if youRatio < 0.30 {
            let pct = Int((1 - youRatio) * 100)
            return PatternResult(type: .initiationImbalance, summary: "\(person.name) initiates \(pct)% of contact", detail: "\(person.name) reaches out far more often than you do. This may reflect scheduling, interest asymmetry, or a dynamic worth reflecting on.", severity: youRatio < 0.15 ? .high : .medium)
        }
        return nil
    }

    private static func checkSentimentDrift(_ person: Person) -> PatternResult? {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let sixtyDaysAgo  = Calendar.current.date(byAdding: .day, value: -60, to: now)!
        let recent = person.interactions.filter { $0.timestamp >= thirtyDaysAgo && $0.sentimentLabel != nil }
        let prev   = person.interactions.filter { $0.timestamp >= sixtyDaysAgo && $0.timestamp < thirtyDaysAgo && $0.sentimentLabel != nil }
        guard recent.count >= 3, prev.count >= 3 else { return nil }
        func anxiousRatio(_ l: [Interaction]) -> Double { Double(l.filter { $0.sentimentLabel == .anxious }.count) / Double(l.count) }
        func secureRatio(_ l: [Interaction])  -> Double { Double(l.filter { $0.sentimentLabel == .secure  }.count) / Double(l.count) }
        let anxiousDelta = anxiousRatio(recent) - anxiousRatio(prev)
        let secureDelta  = secureRatio(recent)  - secureRatio(prev)
        if anxiousDelta > 0.30 {
            return PatternResult(type: .sentimentDrift, summary: "Anxiety rising with \(person.name)", detail: "Your last 30 days with \(person.name) show significantly more anxious interactions than the 30 days before. Something may have shifted in this dynamic recently.", severity: anxiousDelta > 0.50 ? .high : .medium)
        } else if secureDelta > 0.30 {
            return PatternResult(type: .sentimentDrift, summary: "Growing security with \(person.name)", detail: "Your recent interactions with \(person.name) have trended more secure compared to the prior period. This relationship appears to be strengthening.", severity: .low)
        } else if secureDelta < -0.30 {
            return PatternResult(type: .sentimentDrift, summary: "Security declining with \(person.name)", detail: "Your recent interactions with \(person.name) feel less secure than they did a month ago. Worth checking in on what's changed.", severity: abs(secureDelta) > 0.50 ? .high : .medium)
        }
        return nil
    }

    private static func checkContextBehavior(_ person: Person) -> PatternResult? {
        let oneOnOne = person.interactions.filter { $0.locationContext == .oneOnOne }
        let group    = person.interactions.filter { $0.locationContext == .smallGroup || $0.locationContext == .largeGroup }
        guard oneOnOne.count >= 3, group.count >= 3 else { return nil }
        func secureScore(_ l: [Interaction]) -> Double { Double(l.filter { $0.sentimentLabel == .secure }.count) / Double(l.count) }
        let delta = secureScore(oneOnOne) - secureScore(group)
        if delta > 0.35 {
            return PatternResult(type: .contextDependentBehavior, summary: "Much better one-on-one with \(person.name)", detail: "You feel noticeably more secure with \(person.name) in one-on-one settings versus groups. The dynamic changes significantly depending on who else is around.", severity: delta > 0.55 ? .high : .medium)
        } else if delta < -0.35 {
            return PatternResult(type: .contextDependentBehavior, summary: "Better with \(person.name) in groups", detail: "Your interactions with \(person.name) feel more secure in group settings than one-on-one. The presence of others seems to ease this relationship.", severity: abs(delta) > 0.55 ? .high : .medium)
        }
        return nil
    }

    private static func checkPerceptionMismatch(_ person: Person) -> PatternResult? {
        guard person.interactions.count >= 4 else { return nil }
        let mismatches = person.interactions.filter { i in
            i.feelingBefore == .anxious && (i.feelingDuring == .connected || i.feelingDuring == .secure || i.feelingDuring == .authentic)
        }
        let ratio = Double(mismatches.count) / Double(person.interactions.count)
        guard ratio >= 0.30 else { return nil }
        let pct = Int(ratio * 100)
        return PatternResult(type: .perceptionMismatch, summary: "Pre-interaction anxiety doesn't match reality with \(person.name)", detail: "In \(pct)% of interactions, you felt anxious beforehand but connected or secure during. Your anticipatory anxiety about \(person.name) may not reflect how these encounters actually go.", severity: ratio >= 0.50 ? .high : .medium)
    }

    // MARK: - Core: Narrative Builder (Foundation Models → template fallback)

    private static func buildNarrative(
        people: [Person],
        thirtyDaysAgo: Date,
        now: Date,
        patterns: [PatternResult],
        initiationChanges: [InitiationChange]
    ) async -> String {
        let context = buildNarrativeContext(people: people, thirtyDaysAgo: thirtyDaysAgo, now: now, patterns: patterns, initiationChanges: initiationChanges)

        if #available(iOS 26.0, *) {
            if let result = try? await generateWithFoundationModels(context: context) {
                return result
            }
        }
        return templateNarrative(people: people, thirtyDaysAgo: thirtyDaysAgo, now: now)
    }

    @available(iOS 26.0, *)
    private static func generateWithFoundationModels(context: String) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        You're writing a personal relationship digest for someone who tracks their social life. \
        Below is raw data about their interactions over the past 30 days. \
        Write 4–5 sentences that read like a thoughtful friend reflecting on their social patterns — \
        honest, specific, warm but direct. Cover each person mentioned. \
        Notice what's working, what might be draining them, and any patterns worth paying attention to. \
        Don't list stats mechanically. Don't sound like a bot. Don't use bullet points or headers. \
        Just write naturally, as if you know them.

        \(context)
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }

    private static func buildNarrativeContext(
        people: [Person],
        thirtyDaysAgo: Date,
        now: Date,
        patterns: [PatternResult],
        initiationChanges: [InitiationChange]
    ) -> String {
        let df = DateFormatter(); df.dateStyle = .medium
        var lines = ["Period: \(df.string(from: thirtyDaysAgo)) – \(df.string(from: now))"]

        // Per-person breakdown
        let sorted = people.sorted { $0.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count > $1.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count }
        for person in sorted {
            let recentCount = person.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count
            let sentiment = person.dominantSentiment?.rawValue.lowercased() ?? "unclear"
            let initiatorPct = Int(person.initiationRatio * 100)
            let lastSeen = person.daysSinceLastInteraction.map { $0 == 0 ? "today" : "\($0) days ago" } ?? "unknown"
            let feelingAfter = person.mostCommonFeelingAfter?.rawValue.lowercased() ?? "varies"
            lines.append("- \(person.name): \(recentCount) interaction\(recentCount == 1 ? "" : "s"), tone mostly \(sentiment), you initiated \(initiatorPct)%, usually feel \(feelingAfter) after, last contact \(lastSeen)")
        }

        // Top patterns
        if !patterns.isEmpty {
            lines.append("Patterns: " + patterns.map { $0.summary }.joined(separator: "; "))
        }

        // Notable initiation shifts
        let bigShifts = initiationChanges.filter { abs($0.delta) > 0.12 }
        if !bigShifts.isEmpty {
            lines.append("Initiation shifts: " + bigShifts.map { "\($0.personName) went from \(Int($0.previousRatio*100))% to \(Int($0.currentRatio*100))% you-initiated" }.joined(separator: "; "))
        }

        return lines.joined(separator: "\n")
    }

    private static func templateNarrative(people: [Person], thirtyDaysAgo: Date, now: Date) -> String {
        let sorted = people.sorted { $0.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count > $1.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count }
        let mostActive = sorted.first!
        let allRecent = people.flatMap { $0.interactions.filter { $0.timestamp >= thirtyDaysAgo } }
        let secureCount  = allRecent.filter { $0.sentimentLabel == .secure  }.count
        let anxiousCount = allRecent.filter { $0.sentimentLabel == .anxious }.count
        let seed = allRecent.count + people.count

        // Build per-person notes for everyone
        var personNotes: [String] = []
        for person in sorted {
            let count = person.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count
            let feeling = person.mostCommonFeelingAfter
            let initPct = Int(person.initiationRatio * 100)
            let tone = person.dominantSentiment

            var note = "\(person.name)"
            if count == 1 {
                note += " popped up once"
            } else {
                note += " came up \(count) times"
            }
            if let f = feeling {
                let feelingPhrases: [FeelingAfter: [String]] = [
                    .calm:      ["leaving you feeling calm", "usually leaving you settled"],
                    .energized: ["which tends to energize you", "leaving you with more energy"],
                    .drained:   ["though it often leaves you drained", "which has been draining"],
                    .anxious:   ["with a lingering anxious edge", "leaving some anxiety behind"],
                    .satisfied: ["and generally feeling satisfied", "with a sense of satisfaction"],
                    .regretful: ["with some regret afterward", "leaving you second-guessing things"]
                ]
                if let phrases = feelingPhrases[f], !phrases.isEmpty {
                    note += ", " + phrases[seed % phrases.count]
                }
            }
            if initPct > 72 {
                note += " — you're driving most of that contact"
            } else if initPct < 28 {
                note += " — they're the one reaching out"
            }
            if let t = tone, t == .anxious {
                note += " (the dynamic feels a bit anxious)"
            }
            personNotes.append(note)
        }

        // Overall tone sentence
        let overallTone: String
        if secureCount > anxiousCount * 2 {
            let opts = ["Your social world felt relatively steady this month.", "The general vibe has been solid — more grounded than not.", "Things have been feeling pretty secure across the board."]
            overallTone = opts[seed % opts.count]
        } else if anxiousCount > secureCount {
            let opts = ["There's been an anxious thread running through a lot of this.", "More of these interactions left you unsettled than at ease — worth paying attention to.", "The anxiety signal is coming through clearly this period."]
            overallTone = opts[seed % opts.count]
        } else {
            let opts = ["The emotional range here is pretty varied — which makes sense given the mix of people.", "No single tone is dominating, which might mean you're navigating a lot of different dynamics at once.", "Things feel mixed — not great, not bad, just a lot happening."]
            overallTone = opts[seed % opts.count]
        }

        let joined: String
        if personNotes.count == 1 {
            joined = personNotes[0] + "."
        } else if personNotes.count == 2 {
            joined = personNotes[0] + ", while " + personNotes[1].prefix(1).lowercased() + personNotes[1].dropFirst() + "."
        } else {
            let last = personNotes.last!
            let rest = personNotes.dropLast().joined(separator: "; ")
            joined = rest + "; and " + last.prefix(1).lowercased() + last.dropFirst() + "."
        }

        return "\(overallTone) \(joined)"
    }

    // MARK: - Errors

    enum AIError: LocalizedError {
        case insufficientData
        var errorDescription: String? {
            "Not enough data to generate a digest. Log at least 3 interactions with someone first."
        }
    }
}

private extension PatternResult {
    var severityRank: Int {
        switch severity {
        case .high:   return 3
        case .medium: return 2
        case .low:    return 1
        }
    }
}
