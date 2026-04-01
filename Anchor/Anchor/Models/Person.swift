import Foundation
import SwiftData

@Model
final class Person {
    var name: String
    var relationshipType: RelationshipType
    var dateAdded: Date
    var photoData: Data?

    @Relationship(deleteRule: .cascade)
    var interactions: [Interaction] = []

    init(name: String, relationshipType: RelationshipType, dateAdded: Date = .now) {
        self.name = name
        self.relationshipType = relationshipType
        self.dateAdded = dateAdded
    }

    // MARK: - Computed Properties

    var totalInteractions: Int { interactions.count }

    /// Fraction of interactions YOU initiated (0.0–1.0). Excludes "unclear".
    var initiationRatio: Double {
        let meaningful = interactions.filter { $0.initiator != .unclear }
        guard !meaningful.isEmpty else { return 0.5 }
        let youCount = meaningful.filter { $0.initiator == .you }.count
        return Double(youCount) / Double(meaningful.count)
    }

    var lastInteractionDate: Date? {
        interactions.map(\.timestamp).max()
    }

    var daysSinceLastInteraction: Int? {
        guard let last = lastInteractionDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: .now).day
    }

    var mostCommonFeelingAfter: FeelingAfter? {
        let grouped = Dictionary(grouping: interactions.map(\.feelingAfter), by: { $0 })
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }

    var dominantSentiment: SentimentLabel? {
        let labeled = interactions.compactMap(\.sentimentLabel)
        guard !labeled.isEmpty else { return nil }
        let grouped = Dictionary(grouping: labeled, by: { $0 })
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }

    var sentimentDistribution: (anxious: Double, secure: Double, avoidant: Double) {
        let labeled = interactions.compactMap(\.sentimentLabel)
        guard !labeled.isEmpty else { return (0, 0, 0) }
        let t = Double(labeled.count)
        return (
            Double(labeled.filter { $0 == .anxious }.count) / t,
            Double(labeled.filter { $0 == .secure }.count) / t,
            Double(labeled.filter { $0 == .avoidant }.count) / t
        )
    }
}
