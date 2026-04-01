import Foundation

// MARK: - Wire-format DTOs for Supabase REST API
// These mirror the database columns exactly. Never stored in SwiftData.

struct RemotePerson: Codable {
    let id: String
    let userId: String
    let encryptedName: String       // base64 AES-256-GCM ciphertext
    let relationshipType: String
    let dateAdded: String           // ISO8601
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId          = "user_id"
        case encryptedName   = "encrypted_name"
        case relationshipType = "relationship_type"
        case dateAdded       = "date_added"
        case updatedAt       = "updated_at"
    }
}

struct RemoteInteraction: Codable {
    let id: String
    let userId: String
    let personId: String
    let encryptedNote: String?      // base64 AES-256-GCM
    let interactionType: String
    let initiator: String
    let feelingBefore: String
    let feelingDuring: String
    let feelingAfter: String
    let locationContext: String?
    let durationMinutes: Int?
    let sentimentLabel: String?
    let sentimentConfidence: Double?
    let timestamp: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId            = "user_id"
        case personId          = "person_id"
        case encryptedNote     = "encrypted_note"
        case interactionType   = "interaction_type"
        case initiator
        case feelingBefore     = "feeling_before"
        case feelingDuring     = "feeling_during"
        case feelingAfter      = "feeling_after"
        case locationContext   = "location_context"
        case durationMinutes   = "duration_minutes"
        case sentimentLabel    = "sentiment_label"
        case sentimentConfidence = "sentiment_confidence"
        case timestamp
        case updatedAt         = "updated_at"
    }
}

struct RemoteDigest: Codable {
    let id: String
    let userId: String
    let generatedAt: String
    let weekStartDate: String
    let encryptedNarrative: String
    let encryptedPatterns: String
    let encryptedInitiationChanges: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId                      = "user_id"
        case generatedAt                 = "generated_at"
        case weekStartDate               = "week_start_date"
        case encryptedNarrative          = "encrypted_narrative"
        case encryptedPatterns           = "encrypted_patterns"
        case encryptedInitiationChanges  = "encrypted_initiation_changes"
        case updatedAt                   = "updated_at"
    }
}

// Semantic search RPC response
struct SearchResult: Decodable {
    let interactionId: String
    let similarity: Double

    enum CodingKeys: String, CodingKey {
        case interactionId = "interaction_id"
        case similarity
    }
}
