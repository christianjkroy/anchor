import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var showAPIKey = false
    @State private var apiKeyStatus: APIKeyStatus = .unknown
    @State private var isVerifying = false

    enum APIKeyStatus {
        case unknown, valid, invalid
        var icon: String {
            switch self {
            case .unknown: return "key"
            case .valid:   return "checkmark.seal.fill"
            case .invalid: return "xmark.seal.fill"
            }
        }
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .valid:   return AnchorColors.secure
            case .invalid: return AnchorColors.anxious
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    apiKeyRow
                } header: {
                    Text("Claude API")
                } footer: {
                    Text("Get a key at console.anthropic.com. Used for sentiment analysis and weekly digests. Never leaves your device except to call Anthropic's API.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 — Phases 1-4")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Data stored")
                        Spacer()
                        Text("On device (SwiftData)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if let stored = ClaudeService.loadAPIKey() {
                    apiKey = stored
                    apiKeyStatus = .valid
                }
            }
        }
    }

    private var apiKeyRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: apiKeyStatus.icon)
                    .foregroundStyle(apiKeyStatus.color)
                Text("Anthropic API Key")
                Spacer()
                if isVerifying {
                    ProgressView()
                }
            }

            HStack {
                if showAPIKey {
                    TextField("sk-ant-...", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("sk-ant-...", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))

            HStack(spacing: 12) {
                Button("Save") {
                    ClaudeService.saveAPIKey(apiKey)
                    apiKeyStatus = .valid
                    HapticFeedback.success()
                }
                .buttonStyle(.borderedProminent)
                .tint(AnchorColors.secure)
                .disabled(apiKey.isEmpty)

                Button("Verify") {
                    Task { await verifyKey() }
                }
                .buttonStyle(.bordered)
                .tint(AnchorColors.secure)
                .disabled(apiKey.isEmpty || isVerifying)
            }
        }
        .padding(.vertical, 4)
    }

    private func verifyKey() async {
        ClaudeService.saveAPIKey(apiKey)
        isVerifying = true
        defer { isVerifying = false }

        do {
            // Create a minimal test interaction
            let testInteraction = Interaction(
                interactionType: .text,
                initiator: .you,
                feelingBefore: .neutral,
                feelingDuring: .connected,
                feelingAfter: .calm,
                note: "Had a good quick chat"
            )
            _ = try await ClaudeService.shared.classifySentiment(for: testInteraction)
            apiKeyStatus = .valid
            HapticFeedback.success()
        } catch {
            apiKeyStatus = .invalid
        }
    }
}
