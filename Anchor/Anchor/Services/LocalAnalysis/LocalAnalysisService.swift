import Foundation
import SwiftData

/// Sentiment and pattern analysis runs on-device using rule-based logic.
/// Digest narrative is deterministic so it stays clear and reproducible.
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
        case .other:    break
        }

        switch during {
        case .connected, .secure, .authentic: secure   += 2
        case .anxious:                        anxious  += 2
        case .disconnected, .performative:    avoidant += 2
        case .other:                          break
        }

        switch after {
        case .energized, .satisfied: secure   += 3
        case .calm:                  secure   += 2
        case .anxious, .regretful:   anxious  += 3
        case .drained:               avoidant += 3
        case .other:                 break
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
        return templateNarrative(people: people, thirtyDaysAgo: thirtyDaysAgo, now: now)
    }

    private static func templateNarrative(people: [Person], thirtyDaysAgo: Date, now: Date) -> String {
        let sorted = people.sorted { $0.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count > $1.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count }
        let allRecent = people.flatMap { $0.interactions.filter { $0.timestamp >= thirtyDaysAgo } }
        let secureCount  = allRecent.filter { $0.sentimentLabel == .secure  }.count
        let anxiousCount = allRecent.filter { $0.sentimentLabel == .anxious }.count
        let avoidantCount = allRecent.filter { $0.sentimentLabel == .avoidant }.count
        let drainingCount = allRecent.filter { [.drained, .anxious, .regretful].contains($0.feelingAfter) }.count
        let supportiveCount = allRecent.filter { [.calm, .energized, .satisfied].contains($0.feelingAfter) }.count
        let seed = allRecent.count + people.count
        let strainedPeopleCount = people.filter { person in
            let recent = person.interactions.filter { $0.timestamp >= thirtyDaysAgo }
            guard !recent.isEmpty else { return false }
            let recentMeaningful = recent.filter { $0.initiator != .unclear }
            let recentInitiationRatio: Double = {
                guard !recentMeaningful.isEmpty else { return 0.5 }
                return Double(recentMeaningful.filter { $0.initiator == .you }.count) / Double(recentMeaningful.count)
            }()
            let dominantRecentFeeling = Dictionary(grouping: recent.map(\.feelingAfter), by: { $0 })
                .max(by: { $0.value.count < $1.value.count })?.key
            let dominantRecentSentiment = Dictionary(grouping: recent.compactMap(\.sentimentLabel), by: { $0 })
                .max(by: { $0.value.count < $1.value.count })?.key

            return recentInitiationRatio > 0.72
                || dominantRecentFeeling == .drained
                || dominantRecentFeeling == .regretful
                || dominantRecentFeeling == .anxious
                || dominantRecentSentiment == .anxious
                || dominantRecentSentiment == .avoidant
        }.count

        // Build per-person notes for everyone
        var personNotes: [String] = []
        for person in sorted {
            let recentInteractions = person.interactions.filter { $0.timestamp >= thirtyDaysAgo }
            let count = recentInteractions.count
            let feeling = Dictionary(grouping: recentInteractions.map(\.feelingAfter), by: { $0 })
                .max(by: { $0.value.count < $1.value.count })?.key
            let recentMeaningful = recentInteractions.filter { $0.initiator != .unclear }
            let initPct: Int = {
                guard !recentMeaningful.isEmpty else { return 50 }
                let ratio = Double(recentMeaningful.filter { $0.initiator == .you }.count) / Double(recentMeaningful.count)
                return Int(ratio * 100)
            }()
            let tone = Dictionary(grouping: recentInteractions.compactMap(\.sentimentLabel), by: { $0 })
                .max(by: { $0.value.count < $1.value.count })?.key

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
                note += ", and you're driving most of that contact"
            } else if initPct < 28 {
                note += ", and they're the one reaching out"
            }
            if let t = tone, t == .anxious {
                note += ", which still seems to carry some tension"
            }
            personNotes.append(note)
        }

        // Overall tone sentence
        let overallTone: String
        if strainedPeopleCount > 0 && drainingCount > 0 && supportiveCount > 0 {
            let opts = [
                "This stretch feels mixed. Some interactions have been grounding, but at least one relationship is clearly taking more out of you.",
                "There is good here, but it is not settled across the board. Some dynamics feel supportive, while others are still draining.",
                "The overall picture feels uneven. You have some steady moments, but there is still friction in the mix."
            ]
            overallTone = opts[seed % opts.count]
        } else if drainingCount > supportiveCount || strainedPeopleCount >= max(1, people.count / 2) || (anxiousCount + avoidantCount) > secureCount {
            let opts = [
                "This period has felt a bit strained overall.",
                "There is some tension in the mix right now, and it seems worth taking seriously.",
                "The overall read here is not settled. A few dynamics look like they are costing you energy."
            ]
            overallTone = opts[seed % opts.count]
        } else if secureCount > anxiousCount * 2 && supportiveCount >= drainingCount && strainedPeopleCount == 0 {
            let opts = ["Your social world felt relatively steady this month.", "The general vibe has been solid, and more grounded than not.", "Things have been feeling pretty settled across the board."]
            overallTone = opts[seed % opts.count]
        } else if anxiousCount > secureCount {
            let opts = ["There has been a tense thread running through a lot of this.", "More of these interactions left you unsettled than at ease, which feels worth paying attention to.", "The tension signal is coming through clearly this period."]
            overallTone = opts[seed % opts.count]
        } else {
            let opts = ["The emotional range here is pretty varied, which makes sense given the mix of people.", "No single tone is dominating, which probably means you're navigating a lot of different dynamics at once.", "Things feel mixed, not great, not bad, just a lot happening."]
            overallTone = opts[seed % opts.count]
        }

        let joined = joinNarrativeNotes(personNotes)
        return sanitizeNarrative("\(overallTone) \(joined)")
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

private func sanitizeNarrative(_ text: String) -> String {
    text
        .replacingOccurrences(of: "—", with: ",")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func joinNarrativeNotes(_ notes: [String]) -> String {
    guard !notes.isEmpty else { return "" }
    if notes.count == 1 { return notes[0] + "." }
    if notes.count == 2 {
        return notes[0] + ". " + notes[1].prefix(1).uppercased() + notes[1].dropFirst() + "."
    }
    let last = notes.last!
    let rest = notes.dropLast().map { $0 + "." }.joined(separator: " ")
    return rest + " " + last.prefix(1).uppercased() + last.dropFirst() + "."
}
