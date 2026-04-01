import Foundation

enum ClaudePrompts {

    // MARK: - Sentiment Classification

    static func sentimentClassification(note: String, feelingBefore: String, feelingDuring: String, feelingAfter: String) -> String {
        """
        Classify the emotional tone of this interaction note from a relationship tracking app.

        Context:
        - Feeling before: \(feelingBefore)
        - Feeling during: \(feelingDuring)
        - Feeling after: \(feelingAfter)
        - Note: "\(note)"

        Classify the note into exactly one of:
        - "anxious": worry, overthinking, fear of judgment, rumination, second-guessing
        - "secure": comfort, ease, genuine connection, groundedness, trust
        - "avoidant": withdrawal, numbness, detachment, relief from distance, disengagement

        Respond with ONLY a JSON object, no other text:
        {"label": "anxious"|"secure"|"avoidant", "confidence": 0.0-1.0, "reasoning": "one sentence"}
        """
    }

    // MARK: - Pattern Analysis

    struct InteractionSummary: Encodable {
        let timestamp: String
        let interactionType: String
        let initiator: String
        let feelingBefore: String
        let feelingDuring: String
        let feelingAfter: String
        let locationContext: String?
        let sentimentLabel: String?
        let notePreview: String
    }

    static func patternAnalysis(personName: String, relationshipType: String, history: [InteractionSummary]) -> String {
        let historyJSON = (try? String(data: JSONEncoder().encode(history), encoding: .utf8)) ?? "[]"
        return """
        Analyze the interaction history with \(personName) (\(relationshipType)) and identify patterns.

        Interaction history (JSON):
        \(historyJSON)

        Identify up to 3 of the following pattern types if they exist with statistical significance (minimum 4 interactions):

        1. "initiationImbalance" - one person initiates >65% of non-unclear interactions
        2. "sentimentDrift" - sentiment distribution shifted over last 30 days vs prior 30
        3. "contextDependentBehavior" - feelings differ significantly between one-on-one vs group settings
        4. "perceptionMismatch" - stated feelings before contradict behavioral data (e.g., anxious before but connected during and initiated by them)

        For each pattern found, provide plain-English insight without clinical language. Be direct and specific.
        Severity: "low" = mild trend, "medium" = clear pattern, "high" = striking, worth attention.

        Respond with ONLY a JSON array, no other text:
        [{"type": "patternType", "summary": "one-line summary", "detail": "2-3 sentence insight", "severity": "low"|"medium"|"high"}]

        If no significant patterns exist, respond with: []
        """
    }

    // MARK: - Weekly Digest

    struct PersonWeeklySummary: Encodable {
        let name: String
        let relationshipType: String
        let interactionCount: Int
        let initiationRatioCurrent: Double
        let initiationRatioPrevious: Double?
        let sentimentDistribution: SentimentDist
        let topFeelingAfter: String?
        let daysSinceLastInteraction: Int?

        struct SentimentDist: Encodable {
            let anxious: Double
            let secure: Double
            let avoidant: Double
        }
    }

    static func weeklyDigest(summaries: [PersonWeeklySummary], weekStart: String, weekEnd: String) -> String {
        let summariesJSON = (try? String(data: JSONEncoder().encode(summaries), encoding: .utf8)) ?? "[]"
        return """
        Generate a weekly relationship digest for week of \(weekStart) to \(weekEnd).

        Data for people interacted with this week:
        \(summariesJSON)

        Your job:
        1. Write a narrative paragraph (3-5 sentences) summarizing the social week honestly. Note patterns, standouts, or shifts. Be direct — this person tracks their relationships to cut through their own anxious narratives.
        2. Identify the top 3 most significant patterns across all people this week (initiation imbalances, sentiment changes, perception mismatches, context-dependent behavior).
        3. List initiation ratio changes for the top 5 most-interacted people (or fewer if <5 interactions happened).

        Respond with ONLY a JSON object, no other text:
        {
          "narrative": "paragraph text",
          "patterns": [{"type": "patternType", "summary": "one-liner", "detail": "2-3 sentences", "severity": "low"|"medium"|"high"}],
          "initiationChanges": [{"personName": "name", "previousRatio": 0.0, "currentRatio": 0.0}]
        }

        Pattern types: "initiationImbalance", "sentimentDrift", "contextDependentBehavior", "perceptionMismatch"
        """
    }
}
