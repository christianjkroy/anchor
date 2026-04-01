import Foundation
import Security
import SwiftData

actor ClaudeService {
    static let shared = ClaudeService()

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let session = URLSession.shared
    private let sentimentModel = "claude-haiku-4-5-20251001"
    private let digestModel = "claude-opus-4-6"

    // MARK: - API Key (Keychain)

    private static let keychainKey = "com.anchor.claude-api-key"

    static func saveAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func hasAPIKey() -> Bool {
        loadAPIKey() != nil
    }

    // MARK: - Sentiment Classification

    func classifySentiment(for interaction: Interaction) async throws -> (SentimentLabel, Double) {
        guard !interaction.note.isEmpty else {
            throw ClaudeError.emptyNote
        }
        let prompt = ClaudePrompts.sentimentClassification(
            note: interaction.note,
            feelingBefore: interaction.feelingBefore.rawValue,
            feelingDuring: interaction.feelingDuring.rawValue,
            feelingAfter: interaction.feelingAfter.rawValue
        )
        let text = try await send(prompt: prompt, model: sentimentModel, maxTokens: 150)
        let result = try parseJSON(SentimentResult.self, from: text)
        return (result.label, result.confidence)
    }

    func classifyPendingSentiments(for person: Person, context: ModelContext) async throws {
        let unlabeled = person.interactions.filter { $0.sentimentLabel == nil && !$0.note.isEmpty }
        for interaction in unlabeled {
            do {
                let (label, confidence) = try await classifySentiment(for: interaction)
                interaction.sentimentLabel = label
                interaction.sentimentConfidence = confidence
                try? context.save()
            } catch ClaudeError.emptyNote {
                continue
            } catch {
                // Don't propagate partial failures — skip this interaction
                continue
            }
        }
    }

    // MARK: - Pattern Detection

    func detectPatterns(for person: Person) async throws -> [PatternResult] {
        guard person.interactions.count >= 4 else { return [] }

        let df = ISO8601DateFormatter()
        let summaries = person.interactions.map { i in
            ClaudePrompts.InteractionSummary(
                timestamp: df.string(from: i.timestamp),
                interactionType: i.interactionType.rawValue,
                initiator: i.initiator.rawValue,
                feelingBefore: i.feelingBefore.rawValue,
                feelingDuring: i.feelingDuring.rawValue,
                feelingAfter: i.feelingAfter.rawValue,
                locationContext: i.locationContext?.rawValue,
                sentimentLabel: i.sentimentLabel?.rawValue,
                notePreview: String(i.note.prefix(100))
            )
        }

        let prompt = ClaudePrompts.patternAnalysis(
            personName: person.name,
            relationshipType: person.relationshipType.rawValue,
            history: summaries
        )
        let text = try await send(prompt: prompt, model: digestModel, maxTokens: 800)
        return try parseJSON([PatternResult].self, from: text)
    }

    // MARK: - Weekly Digest

    func generateWeeklyDigest(people: [Person]) async throws -> DigestResult {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: now)!

        let active = people.filter { p in
            p.interactions.filter { $0.timestamp >= thirtyDaysAgo }.count >= 3
        }
        guard !active.isEmpty else { throw ClaudeError.insufficientData }

        let summaries = active.map { person -> ClaudePrompts.PersonWeeklySummary in
            let recent = person.interactions.filter { $0.timestamp >= thirtyDaysAgo }
            let prev = person.interactions.filter { $0.timestamp >= sixtyDaysAgo && $0.timestamp < thirtyDaysAgo }

            let prevRatio: Double? = prev.isEmpty ? nil : {
                let meaningful = prev.filter { $0.initiator != .unclear }
                guard !meaningful.isEmpty else { return 0.5 }
                return Double(meaningful.filter { $0.initiator == .you }.count) / Double(meaningful.count)
            }()

            let dist = person.sentimentDistribution

            return ClaudePrompts.PersonWeeklySummary(
                name: person.name,
                relationshipType: person.relationshipType.rawValue,
                interactionCount: recent.count,
                initiationRatioCurrent: person.initiationRatio,
                initiationRatioPrevious: prevRatio,
                sentimentDistribution: .init(anxious: dist.anxious, secure: dist.secure, avoidant: dist.avoidant),
                topFeelingAfter: person.mostCommonFeelingAfter?.rawValue,
                daysSinceLastInteraction: person.daysSinceLastInteraction
            )
        }

        let df = DateFormatter()
        df.dateStyle = .medium
        let weekStart = df.string(from: thirtyDaysAgo)
        let weekEnd = df.string(from: now)

        let prompt = ClaudePrompts.weeklyDigest(summaries: summaries, weekStart: weekStart, weekEnd: weekEnd)
        let text = try await send(prompt: prompt, model: digestModel, maxTokens: 1200)
        return try parseJSON(DigestResult.self, from: text)
    }

    // MARK: - Core HTTP

    private func send(prompt: String, model: String, maxTokens: Int, retries: Int = 3) async throws -> String {
        guard let apiKey = ClaudeService.loadAPIKey() else {
            throw ClaudeError.noAPIKey
        }

        let request = ClaudeRequest(
            model: model,
            maxTokens: maxTokens,
            system: "You are a precise data analyzer. Always respond with valid JSON only, no markdown fences, no prose.",
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )

        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        for attempt in 0..<retries {
            let (data, response) = try await session.data(for: urlRequest)
            let httpResponse = response as! HTTPURLResponse

            switch httpResponse.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
                return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
            case 429:
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
            default:
                throw ClaudeError.invalidResponse(httpResponse.statusCode)
            }
        }
        throw ClaudeError.rateLimited
    }

    // MARK: - JSON Parsing

    private func parseJSON<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        // Strip markdown code fences if present
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```") {
            clean = clean
                .components(separatedBy: "\n")
                .dropFirst()
                .dropLast()
                .joined(separator: "\n")
        }
        guard let data = clean.data(using: .utf8) else {
            throw ClaudeError.decodingFailure("Could not convert text to data")
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ClaudeError.decodingFailure(error.localizedDescription)
        }
    }

    // MARK: - Errors

    enum ClaudeError: LocalizedError {
        case noAPIKey
        case emptyNote
        case insufficientData
        case invalidResponse(Int)
        case decodingFailure(String)
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No API key set. Add your Anthropic API key in Settings."
            case .emptyNote: return "Note is empty."
            case .insufficientData: return "Not enough data to generate a digest."
            case .invalidResponse(let code): return "API returned status \(code)."
            case .decodingFailure(let msg): return "Could not parse response: \(msg)"
            case .rateLimited: return "Rate limited. Try again in a moment."
            }
        }
    }
}
