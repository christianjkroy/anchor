import SwiftUI
import SwiftData

// This file is kept for Xcode project compatibility.
// The actual graph view is GraphTabView (also in this file).

struct GraphPlaceholderView: View {
    var body: some View {
        GraphTabView()
    }
}

// MARK: - Main Graph Tab

struct GraphTabView: View {
    @Query private var people: [Person]
    @State private var viewModel = GraphViewModel()
    @State private var selectedPersonID: PersistentIdentifier? = nil
    @State private var popoverPersonID: PersistentIdentifier? = nil
    @State private var popoverAnchorPoint: CGPoint = .zero
    @State private var showPopover = false
    @State private var dateRangeStart: Date = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now
    @State private var navigateToDetail = false

    var selectedPerson: Person? {
        guard let id = selectedPersonID else { return nil }
        return people.first { $0.persistentModelID == id }
    }

    var popoverPerson: Person? {
        guard let id = popoverPersonID else { return nil }
        return people.first { $0.persistentModelID == id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !RelationshipGraphView.isMetalAvailable {
                    VStack(spacing: 16) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 56))
                            .foregroundStyle(AnchorColors.secure.opacity(0.5))
                        Text("Graph requires a physical device")
                            .font(.headline)
                        Text("Metal GPU rendering isn't available on this simulator. Run on an iPhone to see the live graph.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ZStack(alignment: .bottom) {
                        GeometryReader { geo in
                            RelationshipGraphView(
                                viewModel: viewModel,
                                onNodeTapped: { id in
                                    popoverPersonID = id
                                    popoverAnchorPoint = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                    showPopover = true
                                },
                                onNodeLongPressed: { id, point in
                                    selectedPersonID = id
                                    navigateToDetail = true
                                }
                            )
                            .ignoresSafeArea()
                            .onAppear {
                                viewModel.setViewSize(geo.size)
                                viewModel.rebuild(people: people)
                            }
                            .onChange(of: people.count) { _, _ in
                                viewModel.rebuild(people: people)
                            }
                            .onChange(of: dateRangeStart) { _, newStart in
                                viewModel.dateRange = newStart...Date.now
                                viewModel.rebuild(people: people)
                            }
                        }

                        VStack(spacing: 0) {
                            DateRangeSlider(start: $dateRangeStart)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                        }
                    }
                    .overlay(alignment: .center) {
                        if people.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.largeTitle)
                                    .foregroundStyle(AnchorColors.secure.opacity(0.5))
                                Text("Add people and log interactions to see your relationship graph.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                    .overlay {
                        if showPopover, let person = popoverPerson {
                            NodePopover(person: person, anchorPoint: popoverAnchorPoint) {
                                showPopover = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Relationships")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToDetail) {
                if let person = selectedPerson {
                    PersonDetailView(person: person)
                }
            }
        }
    }
}


// MARK: - Node Popover

private struct NodePopover: View {
    let person: Person
    let anchorPoint: CGPoint
    let dismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 8) {
                Text(person.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    popoverStat(label: "Initiation", value: "\(Int(person.initiationRatio * 100))% you")
                    if let sentiment = person.dominantSentiment {
                        popoverStat(label: "Feeling", value: sentiment.rawValue)
                    }
                }

                if let days = person.daysSinceLastInteraction {
                    popoverStat(label: "Last seen", value: days == 0 ? "Today" : "\(days)d ago")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
            .frame(width: 200)
            .position(
                x: min(max(anchorPoint.x, 110), UIScreen.main.bounds.width - 110),
                y: max(anchorPoint.y - 80, 80)
            )
        }
        .ignoresSafeArea()
    }

    private func popoverStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption).fontWeight(.medium)
        }
    }
}

// MARK: - Date Range Slider

struct DateRangeSlider: View {
    @Binding var start: Date

    private let presets: [(String, Int)] = [
        ("1M", -1), ("3M", -3), ("6M", -6), ("1Y", -12), ("All", -120)
    ]
    @State private var selectedPreset = 1

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(presets.indices, id: \.self) { idx in
                    let (label, months) = presets[idx]
                    Button(label) {
                        selectedPreset = idx
                        start = Calendar.current.date(byAdding: .month, value: months, to: .now) ?? .now
                        HapticFeedback.selection()
                    }
                    .font(.caption)
                    .fontWeight(selectedPreset == idx ? .semibold : .regular)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedPreset == idx ? AnchorColors.secure.opacity(0.2) : Color(.systemGray6))
                    )
                    .foregroundStyle(selectedPreset == idx ? AnchorColors.secure : Color(.label))
                }
            }
        }
    }
}

#Preview {
    GraphPlaceholderView()
        .modelContainer(PreviewData.container())
}
