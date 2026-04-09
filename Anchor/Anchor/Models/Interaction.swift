import Foundation
import SwiftData

@Model
final class Interaction {
    var timestamp: Date
    var interactionType: InteractionType
    var initiator: Initiator
    var durationMinutes: Int?
    var feelingBefore: FeelingBefore
    var feelingDuring: FeelingDuring
    var feelingAfter: FeelingAfter
    var customFeelingBefore: String?
    var customFeelingDuring: String?
    var customFeelingAfter: String?
    var locationContext: LocationContext?
    var note: String
    // Populated in Phase 2
    var sentimentLabel: SentimentLabel?
    var sentimentConfidence: Double?
    // Populated in Phase 5
    var noteEmbedding: [Float]?
    /// Backend UUID, populated after first successful sync.
    var backendId: String?

    var person: Person?

    init(
        timestamp: Date = .now,
        interactionType: InteractionType,
        initiator: Initiator,
        durationMinutes: Int? = nil,
        feelingBefore: FeelingBefore,
        feelingDuring: FeelingDuring,
        feelingAfter: FeelingAfter,
        locationContext: LocationContext? = nil,
        note: String = ""
    ) {
        self.timestamp = timestamp
        self.interactionType = interactionType
        self.initiator = initiator
        self.durationMinutes = durationMinutes
        self.feelingBefore = feelingBefore
        self.feelingDuring = feelingDuring
        self.feelingAfter = feelingAfter
        self.locationContext = locationContext
        self.note = note
    }

    var displayFeelingBefore: String {
        if feelingBefore == .other, let customFeelingBefore, !customFeelingBefore.isEmpty {
            return customFeelingBefore
        }
        return feelingBefore.rawValue
    }

    var displayFeelingDuring: String {
        if feelingDuring == .other, let customFeelingDuring, !customFeelingDuring.isEmpty {
            return customFeelingDuring
        }
        return feelingDuring.rawValue
    }

    var displayFeelingAfter: String {
        if feelingAfter == .other, let customFeelingAfter, !customFeelingAfter.isEmpty {
            return customFeelingAfter
        }
        return feelingAfter.rawValue
    }

    var apiFeelingBefore: String {
        displayFeelingBefore.lowercased()
    }

    var apiFeelingDuring: String {
        displayFeelingDuring.lowercased()
    }

    var apiFeelingAfter: String {
        displayFeelingAfter.lowercased()
    }
}
