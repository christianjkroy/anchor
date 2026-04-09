import Foundation

/// Fire-and-forget backend sync. All operations are best-effort;
/// failures are logged but never surface to the user.
/// Sync runs automatically whenever a server URL and access token are saved.
actor AnchorAPIService {
    static let shared = AnchorAPIService()

    private let defaults = UserDefaults.standard

    // MARK: - Configuration (read from UserDefaults, written by SettingsView via @AppStorage)

    var baseURL: String {
        let saved = defaults.string(forKey: "anchorAPIBaseURL")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !saved.isEmpty { return saved }
        #if targetEnvironment(simulator)
        return "http://localhost:3001"
        #else
        return ""
        #endif
    }
    var token: String {
        defaults.string(forKey: "anchorAPIToken")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isConfigured: Bool {
        !baseURL.isEmpty && !token.isEmpty
    }

    // MARK: - Person sync

    /// POST /api/persons. Returns the backend UUID on success.
    func syncPerson(name: String, relationshipType: String) async -> String? {
        guard isConfigured,
              let url = URL(string: "\(baseURL)/api/persons") else { return nil }

        let body: [String: Any] = [
            "name": name,
            "relationshipType": relationshipType,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        let req = urlRequest(url: url, method: "POST", body: data)
        do {
            let (responseData, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            return json?["id"] as? String
        } catch {
            print("[AnchorAPIService] syncPerson failed: \(error)")
            return nil
        }
    }

    // MARK: - Interaction sync

    /// POST /api/interactions. Returns the backend UUID on success.
    func syncInteraction(
        backendPersonId: String,
        type: String,
        initiatedBy: String,
        feelingBefore: String,
        feelingDuring: String,
        feelingAfter: String,
        locationContext: String?,
        durationMinutes: Int?,
        note: String
    ) async -> String? {
        guard isConfigured,
              let url = URL(string: "\(baseURL)/api/interactions") else { return nil }

        var body: [String: Any] = [
            "personId":      backendPersonId,
            "type":          type,
            "initiatedBy":   initiatedBy,
            "feelingBefore": feelingBefore,
            "feelingDuring": feelingDuring,
            "feelingAfter":  feelingAfter,
            "note":          note,
        ]
        if let lc = locationContext { body["locationContext"] = lc }
        if let dm = durationMinutes { body["durationMinutes"] = dm }

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        do {
            let (responseData, _) = try await URLSession.shared.data(for: urlRequest(url: url, method: "POST", body: data))
            let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            return json?["id"] as? String
        } catch {
            print("[AnchorAPIService] syncInteraction failed: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func urlRequest(url: URL, method: String, body: Data) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        req.timeoutInterval = 10
        return req
    }
}

// MARK: - Enum → backend string mapping

extension InteractionType {
    var backendValue: String {
        switch self {
        case .inPerson:     return "hangout"
        case .text:         return "text"
        case .call:         return "call"
        case .socialMedia:  return "text"
        case .groupHangout: return "group"
        }
    }
}

extension Initiator {
    var backendValue: String {
        switch self {
        case .you:    return "user"
        case .them:   return "them"
        case .mutual: return "unclear"
        case .unclear: return "unclear"
        }
    }
}
