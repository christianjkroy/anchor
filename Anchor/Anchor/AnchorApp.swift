import SwiftUI
import SwiftData
import UserNotifications

@main
struct AnchorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("lastDigestTimestamp") private var lastDigestTimestamp: Double = 0

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(isComplete: $hasCompletedOnboarding)
            }
        }
        .modelContainer(for: [Person.self, Interaction.self, Pattern.self, WeeklyDigest.self])
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await DigestNotificationService.requestAuthorization()
                    await checkAndGenerateDigest()
                }
            }
        }
    }

    @MainActor
    private func checkAndGenerateDigest() async {
        guard ClaudeService.hasAPIKey() else { return }

        let last = lastDigestTimestamp == 0 ? nil : Date(timeIntervalSince1970: lastDigestTimestamp)
        guard shouldGenerateDigest(lastDate: last) else { return }

        do {
            let container = try ModelContainer(for: Person.self, Interaction.self, Pattern.self, WeeklyDigest.self)
            let context = container.mainContext
            let people = try context.fetch(FetchDescriptor<Person>())

            let result = try await ClaudeService.shared.generateWeeklyDigest(people: people)
            let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
            let digest = WeeklyDigest(
                weekStartDate: weekStart,
                narrativeParagraph: result.narrative,
                initiationChanges: result.initiationChanges
            )
            for p in result.patterns {
                let pattern = Pattern(patternType: p.type, summary: p.summary, detail: p.detail, severity: p.severity)
                digest.patterns.append(pattern)
                context.insert(pattern)
            }
            context.insert(digest)
            try context.save()

            lastDigestTimestamp = Date.now.timeIntervalSince1970
            HapticFeedback.success()
            DigestNotificationService.scheduleImmediateNotification(for: digest)
        } catch {
            // Silently fail background digest generation
        }
    }

    private func shouldGenerateDigest(lastDate: Date?) -> Bool {
        guard let last = lastDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
        return days >= 7
    }
}
