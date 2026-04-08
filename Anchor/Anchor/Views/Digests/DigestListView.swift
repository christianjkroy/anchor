import SwiftUI
import SwiftData

struct DigestListView: View {
    @Query(sort: \WeeklyDigest.generatedAt, order: .reverse) private var digests: [WeeklyDigest]
    @Environment(\.modelContext) private var modelContext
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if digests.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(digests) { digest in
                                NavigationLink(destination: DigestDetailView(digest: digest)) {
                                    DigestRowView(digest: digest)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.secondarySystemGroupedBackground))
                                                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        modelContext.delete(digest)
                                        try? modelContext.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Digests")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await generateDigest() }
                    } label: {
                        if isGenerating {
                            ProgressView().tint(AnchorColors.secure)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(AnchorColors.secure)
                        }
                    }
                    .disabled(isGenerating)
                }
            }
            .alert("Could not generate digest", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundStyle(AnchorColors.secure)
            Text("No Digests Yet")
                .font(.headline)
            Text("Digests generate weekly. Log at least 3 interactions with someone to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Generate Now") {
                Task { await generateDigest() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AnchorColors.secure)
            .disabled(isGenerating)
        }
        .padding()
    }

    private func generateDigest() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let descriptor = FetchDescriptor<Person>()
            let people = try modelContext.fetch(descriptor)

            let result = try await ClaudeService.shared.generateWeeklyDigest(people: people)

            let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
            let digest = WeeklyDigest(
                weekStartDate: weekStart,
                narrativeParagraph: result.narrative,
                initiationChanges: result.initiationChanges
            )

            for p in result.patterns {
                let pattern = Pattern(
                    patternType: p.type,
                    summary: p.summary,
                    detail: p.detail,
                    severity: p.severity
                )
                digest.patterns.append(pattern)
                modelContext.insert(pattern)
            }

            modelContext.insert(digest)
            try? modelContext.save()

            HapticFeedback.success()
            DigestNotificationService.scheduleImmediateNotification(for: digest)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteDigests(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(digests[index])
        }
        try? modelContext.save()
    }
}

private struct DigestRowView: View {
    let digest: WeeklyDigest

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .center, spacing: 6) {
                ZStack {
                    Circle()
                        .fill(AnchorColors.secure.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 18))
                        .foregroundStyle(AnchorColors.secure)
                }
                if !digest.isRead {
                    Circle()
                        .fill(AnchorColors.secure)
                        .frame(width: 6, height: 6)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(digest.weekDateRangeString)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(digest.narrativeParagraph.prefix(120) + "…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)

                HStack(spacing: 10) {
                    Label("\(digest.patterns.count) pattern\(digest.patterns.count == 1 ? "" : "s")", systemImage: "waveform.path.ecg")
                        .font(.caption2)
                        .foregroundStyle(AnchorColors.secure)

                    if !digest.initiationChanges.isEmpty {
                        Label("\(digest.initiationChanges.count) shift\(digest.initiationChanges.count == 1 ? "" : "s")", systemImage: "arrow.left.arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
    }
}

#Preview {
    DigestListView()
        .modelContainer(PreviewData.container())
}
