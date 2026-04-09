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

    private var graphSnapshotKey: String {
        displayedPeople.map {
            [
                String(describing: $0.persistentModelID),
                $0.name,
                String($0.interactions.count),
                String($0.lastInteractionDate?.timeIntervalSince1970 ?? 0),
                $0.dominantSentiment?.rawValue ?? "none"
            ].joined(separator: "|")
        }
        .joined(separator: "||")
    }

    private var displayedPeople: [Person] {
        people.filter { person in
            !person.interactions.filter { $0.timestamp >= dateRangeStart && $0.timestamp <= Date.now }.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 0.98),
                        Color(red: 0.93, green: 0.97, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                GeometryReader { geo in
                    SwiftUIGraphView(
                        viewModel: viewModel,
                        onNodeTapped: { id in
                            selectedPersonID = id
                            navigateToDetail = true
                        },
                        onNodeLongPressed: { id, point in
                            popoverPersonID = id
                            popoverAnchorPoint = point
                            showPopover = true
                        }
                    )
                    .onAppear {
                        viewModel.setViewSize(geo.size)
                        viewModel.dateRange = dateRangeStart...Date.now
                        viewModel.rebuild(people: people)
                    }
                    .onChange(of: geo.size) { _, newSize in
                        viewModel.setViewSize(newSize)
                        viewModel.rebuild(people: people)
                    }
                    .onChange(of: graphSnapshotKey) { _, _ in
                        viewModel.rebuild(people: people)
                    }
                    .onChange(of: dateRangeStart) { _, newStart in
                        viewModel.dateRange = newStart...Date.now
                        viewModel.rebuild(people: people)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                GraphLegend(peopleCount: displayedPeople.count)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) {
                DateRangeSlider(start: $dateRangeStart)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .overlay(alignment: .center) {
                if displayedPeople.isEmpty {
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
            .navigationTitle("Relationships")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToDetail) {
                if let person = selectedPerson {
                    PersonDetailView(person: person)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

private struct GraphLegend: View {
    let peopleCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Relationship Map")
                        .font(.headline)
                    Text("Tap a node to open the full profile. Long-press for a quick snapshot.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(peopleCount) people")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AnchorColors.secure.opacity(0.12)))
                    .foregroundStyle(AnchorColors.secure)
            }

            HStack(spacing: 12) {
                legendItem(color: AnchorColors.secure, label: SentimentLabel.secure.displayName)
                legendItem(color: AnchorColors.anxious, label: SentimentLabel.anxious.displayName)
                legendItem(color: AnchorColors.avoidant, label: SentimentLabel.avoidant.displayName)
                legendItem(color: AnchorColors.neutral, label: "No read yet")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func legendItem(color: Color, label: String) -> some View {
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

private struct SwiftUIGraphView: View {
    let viewModel: GraphViewModel
    let onNodeTapped: (PersistentIdentifier) -> Void
    let onNodeLongPressed: (PersistentIdentifier, CGPoint) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    for edge in viewModel.edges {
                        guard edge.sourceIndex < viewModel.nodes.count, edge.targetIndex < viewModel.nodes.count else { continue }
                        let source = viewModel.nodes[edge.sourceIndex]
                        let target = viewModel.nodes[edge.targetIndex]
                        var path = Path()
                        path.move(to: displayedPoint(for: source))
                        path.addLine(to: displayedPoint(for: target))
                        context.stroke(
                            path,
                            with: .color(Color(.systemGray3).opacity(min(Double(edge.weight) / 5.0, 0.65))),
                            lineWidth: CGFloat(max(1.5, edge.weight))
                        )
                    }
                }

                ForEach(viewModel.nodes) { node in
                    let point = displayedPoint(for: node)
                    Button {
                        onNodeTapped(node.id)
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(nodeColor(node.color))
                                .frame(width: CGFloat(node.radius), height: CGFloat(node.radius))
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)

                            Text(node.label)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                            onNodeLongPressed(node.id, point)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onAppear {
                viewModel.setViewSize(geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                viewModel.setViewSize(newSize)
            }
        }
    }

    private func displayedPoint(for node: GraphViewModel.Node) -> CGPoint {
        CGPoint(x: CGFloat(node.position.x), y: CGFloat(node.position.y))
    }

    private func nodeColor(_ value: SIMD4<Float>) -> Color {
        Color(
            red: Double(value.x),
            green: Double(value.y),
            blue: Double(value.z),
            opacity: Double(value.w)
        )
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
                        popoverStat(label: "Tone", value: sentiment.displayName)
                    }
                }

                if let days = person.daysSinceLastInteraction {
                    popoverStat(label: "Last seen", value: days == 0 ? "Today" : "\(days)d ago")
                }

                Text("Long-press gives you a quick summary. Tap opens the full profile.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: 2) {
                Text("Date range")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Filter the relationship map")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 10)

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
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedPreset == idx ? AnchorColors.secure.opacity(0.2) : Color(.systemGray6))
                    )
                    .foregroundStyle(selectedPreset == idx ? AnchorColors.secure : Color(.label))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    GraphPlaceholderView()
        .modelContainer(PreviewData.container())
}
