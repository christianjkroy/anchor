import Foundation

// MARK: - Result types used by local analysis services

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
