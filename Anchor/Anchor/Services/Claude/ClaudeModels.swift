import Foundation

// MARK: - Request

struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Response

struct ClaudeResponse: Decodable {
    let content: [ClaudeContentBlock]
    let usage: ClaudeUsage
}

struct ClaudeContentBlock: Decodable {
    let type: String
    let text: String?
}

struct ClaudeUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Decoded result types

struct SentimentResult: Decodable {
    let label: SentimentLabel
    let confidence: Double
    let reasoning: String
}

struct PatternResult: Decodable {
    let type: PatternType
    let summary: String
    let detail: String
    let severity: PatternSeverity
}

struct DigestResult: Decodable {
    let narrative: String
    let patterns: [PatternResult]
    let initiationChanges: [InitiationChange]
}

struct InitiationChange: Codable {
    let personName: String
    let previousRatio: Double
    let currentRatio: Double

    var delta: Double { currentRatio - previousRatio }
}
