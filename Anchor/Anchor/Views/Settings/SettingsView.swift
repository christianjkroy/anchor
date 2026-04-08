import SwiftUI

struct SettingsView: View {
    @AppStorage("anchorSyncEnabled") private var syncEnabled = false
    @AppStorage("anchorAPIBaseURL")  private var apiBaseURL  = ""
    @AppStorage("anchorAPIToken")    private var apiToken    = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Analysis") {
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

                Section {
                    Toggle("Enable backend sync", isOn: $syncEnabled)

                    if syncEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server URL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("http://192.168.x.x:3001", text: $apiBaseURL)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auth token (JWT)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SecureField("Paste your token here", text: $apiToken)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        Text("New people and interactions will sync to your backend after being saved locally. Sync failures are silent — local data is always the source of truth.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Backend Sync")
                } footer: {
                    if syncEnabled && !apiBaseURL.isEmpty {
                        Text("Syncing to \(apiBaseURL)")
                            .font(.caption2)
                    }
                }

                Section("About") {
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
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
