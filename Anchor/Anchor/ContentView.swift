import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GraphPlaceholderView()
                .tabItem {
                    Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }

            PeopleListView()
                .tabItem {
                    Label("People", systemImage: "person.2.fill")
                }

            DigestListView()
                .tabItem {
                    Label("Digests", systemImage: "chart.bar.doc.horizontal")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(AnchorColors.secure)
    }
}
