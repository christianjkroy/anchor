import SwiftUI
import SwiftData

@main
struct AnchorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Person.self, Interaction.self])
    }
}
