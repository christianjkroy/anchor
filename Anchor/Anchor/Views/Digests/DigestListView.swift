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
                    List {
                        ForEach(digests) { digest in
                            NavigationLink(destination: DigestDetailView(digest: digest)) {
                                DigestRowView(digest: digest)
                            }
                        }
                    }
                    .listStyle(.plain)
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
        guard ClaudeService.hasAPIKey() else {
            errorMessage = "No API key set. Add your Anthropic key in Settings."
            return
        }
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
}

private struct DigestRowView: View {
    let digest: WeeklyDigest

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !digest.isRead {
                Circle()
                    .fill(AnchorColors.secure)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            } else {
                Spacer().frame(width: 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(digest.weekDateRangeString)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(digest.narrativeParagraph.prefix(100) + "…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(digest.patterns.count) pattern\(digest.patterns.count == 1 ? "" : "s") detected")
                    .font(.caption2)
                    .foregroundStyle(AnchorColors.secure)
            }
        }
        .padding(.vertical, 4)
    }
}
