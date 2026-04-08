import SwiftUI

struct SettingsView: View {
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

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
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
        }
    }
}

#Preview {
    SettingsView()
}
