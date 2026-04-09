import SwiftUI

// MARK: - Color Palette

enum AnchorColors {
    static let anxious  = Color(red: 0.93, green: 0.60, blue: 0.57)  // soft coral
    static let secure   = Color(red: 0.47, green: 0.78, blue: 0.74)  // soft teal
    static let avoidant = Color(red: 0.72, green: 0.72, blue: 0.74)  // muted grey
    static let neutral  = Color(red: 0.65, green: 0.82, blue: 0.93)  // light blue
}

// MARK: - Enums

enum RelationshipType: String, CaseIterable, Codable, Hashable {
    case acquaintance = "Acquaintance"
    case friend       = "Friend"
    case closeFriend  = "Close Friend"
    case family       = "Family"
    case romantic     = "Romantic"

    var color: Color {
        switch self {
        case .acquaintance: return Color(.systemGray3)
        case .friend:       return AnchorColors.secure
        case .closeFriend:  return Color(red: 0.35, green: 0.68, blue: 0.64)
        case .family:       return AnchorColors.neutral
        case .romantic:     return AnchorColors.anxious
        }
    }
}

enum InteractionType: String, CaseIterable, Codable, Hashable {
    case inPerson     = "In Person"
    case text         = "Text"
    case call         = "Call"
    case socialMedia  = "Social Media"
    case groupHangout = "Group Hangout"

    var systemImage: String {
        switch self {
        case .inPerson:     return "person.2.fill"
        case .text:         return "message.fill"
        case .call:         return "phone.fill"
        case .socialMedia:  return "globe"
        case .groupHangout: return "person.3.fill"
        }
    }
}

enum Initiator: String, CaseIterable, Codable, Hashable {
    case you    = "You"
    case them   = "Them"
    case mutual = "Mutual"
    case unclear = "Unclear"
}

enum FeelingBefore: String, CaseIterable, Codable, Hashable {
    case anxious  = "Anxious"
    case neutral  = "Neutral"
    case excited  = "Excited"
    case avoidant = "Avoidant"
    case other    = "Other"

    var color: Color {
        switch self {
        case .anxious:  return AnchorColors.anxious
        case .neutral:  return AnchorColors.neutral
        case .excited:  return Color(red: 0.88, green: 0.78, blue: 0.55)
        case .avoidant: return AnchorColors.avoidant
        case .other:    return AnchorColors.neutral
        }
    }
}

enum FeelingDuring: String, CaseIterable, Codable, Hashable {
    case connected    = "Connected"
    case disconnected = "Disconnected"
    case anxious      = "Anxious"
    case secure       = "Secure"
    case performative = "Performative"
    case authentic    = "Authentic"
    case other        = "Other"

    var color: Color {
        switch self {
        case .connected:    return AnchorColors.secure
        case .disconnected: return AnchorColors.avoidant
        case .anxious:      return AnchorColors.anxious
        case .secure:       return AnchorColors.secure
        case .performative: return AnchorColors.neutral
        case .authentic:    return Color(red: 0.53, green: 0.81, blue: 0.65)
        case .other:        return AnchorColors.neutral
        }
    }
}

enum FeelingAfter: String, CaseIterable, Codable, Hashable {
    case drained   = "Drained"
    case energized = "Energized"
    case anxious   = "Anxious"
    case calm      = "Calm"
    case regretful = "Regretful"
    case satisfied = "Satisfied"
    case other     = "Other"

    var color: Color {
        switch self {
        case .drained:   return AnchorColors.avoidant
        case .energized: return AnchorColors.secure
        case .anxious:   return AnchorColors.anxious
        case .calm:      return AnchorColors.neutral
        case .regretful: return AnchorColors.anxious
        case .satisfied: return AnchorColors.secure
        case .other:     return AnchorColors.neutral
        }
    }
}

enum LocationContext: String, CaseIterable, Codable, Hashable {
    case oneOnOne   = "One-on-One"
    case smallGroup = "Small Group"
    case largeGroup = "Large Group"
}

enum SentimentLabel: String, CaseIterable, Codable, Hashable {
    case anxious  = "Anxious"
    case secure   = "Secure"
    case avoidant = "Avoidant"

    var color: Color {
        switch self {
        case .anxious:  return AnchorColors.anxious
        case .secure:   return AnchorColors.secure
        case .avoidant: return AnchorColors.avoidant
        }
    }
}
