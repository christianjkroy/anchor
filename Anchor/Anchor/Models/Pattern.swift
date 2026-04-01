import Foundation
import SwiftData

@Model
final class Pattern {
    var id: UUID
    var patternTypeRaw: String
    var summary: String
    var detail: String
    var severityRaw: String
    var detectedAt: Date
    var isRead: Bool
    var personName: String?

    var weeklyDigest: WeeklyDigest?

    init(
        id: UUID = .init(),
        patternType: PatternType,
        summary: String,
        detail: String,
        severity: PatternSeverity,
        personName: String? = nil,
        detectedAt: Date = .now
    ) {
        self.id = id
        self.patternTypeRaw = patternType.rawValue
        self.summary = summary
        self.detail = detail
        self.severityRaw = severity.rawValue
        self.personName = personName
        self.detectedAt = detectedAt
        self.isRead = false
    }

    var patternType: PatternType {
        PatternType(rawValue: patternTypeRaw) ?? .initiationImbalance
    }

    var severity: PatternSeverity {
        PatternSeverity(rawValue: severityRaw) ?? .low
    }
}

enum PatternType: String, Codable, CaseIterable {
    case initiationImbalance      = "initiationImbalance"
    case sentimentDrift           = "sentimentDrift"
    case contextDependentBehavior = "contextDependentBehavior"
    case perceptionMismatch       = "perceptionMismatch"

    var displayName: String {
        switch self {
        case .initiationImbalance:      return "Initiation Imbalance"
        case .sentimentDrift:           return "Sentiment Drift"
        case .contextDependentBehavior: return "Context-Dependent Behavior"
        case .perceptionMismatch:       return "Perception Mismatch"
        }
    }

    var systemImage: String {
        switch self {
        case .initiationImbalance:      return "arrow.left.arrow.right"
        case .sentimentDrift:           return "chart.line.downtrend.xyaxis"
        case .contextDependentBehavior: return "person.2.wave.2"
        case .perceptionMismatch:       return "brain.head.profile"
        }
    }
}

enum PatternSeverity: String, Codable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"
}
