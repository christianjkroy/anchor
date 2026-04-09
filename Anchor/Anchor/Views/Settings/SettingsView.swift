import SwiftUI

struct SettingsView: View {
    @AppStorage("anchorAPIBaseURL")  private var apiBaseURL  = ""
    @AppStorage("anchorAPIToken")    private var apiToken    = ""

    private var isBackendConfigured: Bool {
        !normalizedBaseURL.isEmpty && !normalizedToken.isEmpty
    }

    private var normalizedBaseURL: String {
        apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedToken: String {
        apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Analysis")) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundStyle(AnchorColors.secure)
                        Text("Sentiment & patterns")
                        Spacer()
                        Text("On-device")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                Section(
                    header: Text("Sync"),
                    footer: Text("Anchor works fully on-device by default. If you add a server URL and access token, syncing starts automatically in the background. The access token is just your backend sign-in token.")
                        .font(.caption2)
                ) {
                    HStack {
                        Label("Backend connection", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text(isBackendConfigured ? "Automatic" : "Local only")
                            .foregroundStyle(isBackendConfigured ? AnchorColors.secure : .secondary)
                            .font(.subheadline)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("http://localhost:3001", text: $apiBaseURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Access token")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Paste your backend sign-in token", text: $apiToken)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    if isBackendConfigured {
                        Button(role: .destructive) {
                            apiBaseURL = ""
                            apiToken = ""
                        } label: {
                            Text("Clear backend connection")
                        }
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Primary storage")
                        Spacer()
                        Text("On-device (SwiftData)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .onAppear {
                #if targetEnvironment(simulator)
                if apiBaseURL.isEmpty {
                    apiBaseURL = "http://localhost:3001"
                }
                #endif
            }
        }
    }
}

#Preview {
    SettingsView()
}
