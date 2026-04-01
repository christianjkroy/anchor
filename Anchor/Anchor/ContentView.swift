import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PeopleListView()
                .tabItem {
                    Label("People", systemImage: "person.2.fill")
                }

            GraphPlaceholderView()
                .tabItem {
                    Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }
        }
        .tint(AnchorColors.secure)
    }
}
