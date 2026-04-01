import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]
    @State private var searchText = ""
    @State private var showAddPerson = false

    private var displayedPeople: [Person] {
        let filtered = searchText.isEmpty
            ? people
            : people.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted {
            ($0.lastInteractionDate ?? $0.dateAdded) > ($1.lastInteractionDate ?? $1.dateAdded)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if displayedPeople.isEmpty && searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No People Yet", systemImage: "person.2")
                    } description: {
                        Text("Tap + to add someone and start tracking your interactions.")
                    } actions: {
                        Button("Add Person") { showAddPerson = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(displayedPeople) { person in
                            NavigationLink(destination: PersonDetailView(person: person)) {
                                PersonRowView(person: person)
                            }
                        }
                        .onDelete(perform: deletePeople)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Anchor")
            .searchable(text: $searchText, prompt: "Search people")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPerson = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AnchorColors.secure)
                    }
                }
            }
            .sheet(isPresented: $showAddPerson) {
                AddPersonView()
            }
        }
    }

    private func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(displayedPeople[index])
        }
    }
}
