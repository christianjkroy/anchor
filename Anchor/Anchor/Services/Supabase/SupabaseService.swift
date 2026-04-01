import Foundation
import Network
import UIKit

// MARK: - Supabase configuration
// Set these before shipping. Add to environment or secure config.
// IMPORTANT: Replace with your actual Supabase project URL and anon key.
private let supabaseURL = "https://YOUR_PROJECT.supabase.co"
private let supabaseAnonKey = "YOUR_ANON_KEY"

actor SupabaseService {
    static let shared = SupabaseService()

    private let session = URLSession.shared
    private let monitor = NWPathMonitor()
    private var isOnWiFi = false
    private var userID: String? = nil
    private var accessToken: String? = nil

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.updateConnectivity(path) }
        }
        monitor.start(queue: DispatchQueue(label: "com.anchor.network-monitor"))
    }

    private func updateConnectivity(_ path: NWPath) {
        isOnWiFi = path.usesInterfaceType(.wifi)
    }

    // MARK: - Auth (Apple Sign In)

    func signIn(identityToken: String, nonce: String) async throws -> String {
        let body: [String: Any] = [
            "provider": "apple",
            "id_token": identityToken,
            "nonce": nonce,
            "access_token": identityToken
        ]
        let response = try await post(path: "/auth/v1/token?grant_type=id_token", body: body, auth: false)
        guard let token = response["access_token"] as? String,
              let user = response["user"] as? [String: Any],
              let uid = user["id"] as? String else {
            throw SupabaseError.authFailed
        }
        self.accessToken = token
        self.userID = uid
        return uid
    }

    func signOut() async {
        accessToken = nil
        userID = nil
    }

    // MARK: - Sync

    func shouldSync() -> Bool {
        isOnWiFi && userID != nil && accessToken != nil
    }

    func syncPeople(_ people: [Person]) async throws {
        guard shouldSync(), let uid = userID else { return }
        let iso = ISO8601DateFormatter()

        for person in people {
            let encName = try EncryptionService.encryptString(person.name).base64EncodedString()
            let dto: [String: Any?] = [
                "id": person.persistentModelID.hashValue.description,
                "user_id": uid,
                "encrypted_name": encName,
                "relationship_type": person.relationshipType.rawValue,
                "date_added": iso.string(from: person.dateAdded),
                "updated_at": iso.string(from: Date.now)
            ]
            _ = try await upsert(table: "people", row: dto.compactMapValues { $0 })
        }
    }

    func syncInteractions(for people: [Person]) async throws {
        guard shouldSync(), let uid = userID else { return }
        let iso = ISO8601DateFormatter()

        for person in people {
            let personRemoteID = person.persistentModelID.hashValue.description
            for interaction in person.interactions {
                var row: [String: Any?] = [
                    "id": interaction.persistentModelID.hashValue.description,
                    "user_id": uid,
                    "person_id": personRemoteID,
                    "interaction_type": interaction.interactionType.rawValue,
                    "initiator": interaction.initiator.rawValue,
                    "feeling_before": interaction.feelingBefore.rawValue,
                    "feeling_during": interaction.feelingDuring.rawValue,
                    "feeling_after": interaction.feelingAfter.rawValue,
                    "location_context": interaction.locationContext?.rawValue,
                    "duration_minutes": interaction.durationMinutes,
                    "sentiment_label": interaction.sentimentLabel?.rawValue,
                    "sentiment_confidence": interaction.sentimentConfidence,
                    "timestamp": iso.string(from: interaction.timestamp),
                    "updated_at": iso.string(from: Date.now)
                ]
                if !interaction.note.isEmpty {
                    row["encrypted_note"] = try EncryptionService.encryptString(interaction.note).base64EncodedString()
                }
                _ = try await upsert(table: "interactions", row: row.compactMapValues { $0 })
            }
        }
    }

    // MARK: - Semantic Search (full-text fallback until pgvector embedding is wired)

    func searchInteractions(query: String) async throws -> [String] {
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }

        var components = URLComponents(string: supabaseURL + "/rest/v1/interactions")!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id"),
            URLQueryItem(name: "encrypted_note", value: "fts.\(query)")
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

        let (data, _) = try await session.data(for: request)
        let results = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        return results.compactMap { $0["id"] as? String }
    }

    // MARK: - HTTP helpers

    private func post(path: String, body: [String: Any], auth: Bool) async throws -> [String: Any] {
        guard let url = URL(string: supabaseURL + path) else { throw SupabaseError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        if auth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        guard (200..<300).contains(http.statusCode) else { throw SupabaseError.httpError(http.statusCode) }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func upsert(table: String, row: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: supabaseURL + "/rest/v1/\(table)") else { throw SupabaseError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: row)
        let (data, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse
        guard (200..<300).contains(http.statusCode) else { throw SupabaseError.httpError(http.statusCode) }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Errors

    enum SupabaseError: LocalizedError {
        case authFailed
        case notAuthenticated
        case invalidURL
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .authFailed: return "Authentication failed."
            case .notAuthenticated: return "Not signed in."
            case .invalidURL: return "Invalid Supabase URL."
            case .httpError(let code): return "Supabase returned \(code)."
            }
        }
    }
}
