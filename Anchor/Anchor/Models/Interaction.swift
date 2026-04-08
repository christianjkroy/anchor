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
}
