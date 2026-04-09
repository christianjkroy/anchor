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
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if displayedPeople.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            PeopleLegendView()
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        Section {
                            ForEach(displayedPeople) { person in
                                NavigationLink(destination: PersonDetailView(person: person)) {
                                    PersonRowView(person: person)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.secondarySystemGroupedBackground))
                                                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deletePerson(person)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("People")
            .searchable(text: $searchText, prompt: "Search people")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPerson = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(AnchorColors.secure)
                                .frame(width: 32, height: 32)
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddPerson) {
                AddPersonView()
            }
        }
    }

    private func deletePerson(_ person: Person) {
        modelContext.delete(person)
        try? modelContext.save()
        HapticFeedback.selection()
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AnchorColors.secure.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(AnchorColors.secure)
            }
            VStack(spacing: 8) {
                Text("No People Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Add someone to start tracking your interactions and relationship patterns.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button {
                showAddPerson = true
            } label: {
                Label("Add Person", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(AnchorColors.secure)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct PeopleLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Row color shows the dominant tone of your logged interactions with that person.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                item(color: AnchorColors.secure, label: "Secure")
                item(color: AnchorColors.anxious, label: "Anxious")
                item(color: AnchorColors.avoidant, label: "Avoidant")
                item(color: AnchorColors.neutral, label: "No sentiment yet")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func item(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PeopleListView()
        .modelContainer(PreviewData.container())
}
