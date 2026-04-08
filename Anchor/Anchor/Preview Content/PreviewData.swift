import SwiftData
import Foundation

// Shared mock data and container for SwiftUI previews
@MainActor
enum PreviewData {

    static func container() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Person.self, Interaction.self, Pattern.self, WeeklyDigest.self,
            configurations: config
        )
        let ctx = container.mainContext

        // People
        let alex = Person(name: "Alex Chen", relationshipType: .closeFriend)
        let jordan = Person(name: "Jordan", relationshipType: .romantic)
        let sam = Person(name: "Sam Rivera", relationshipType: .friend)
        ctx.insert(alex); ctx.insert(jordan); ctx.insert(sam)

        // Interactions for Alex
        let i1 = Interaction(interactionType: .inPerson, initiator: .you,
                             feelingBefore: .anxious, feelingDuring: .connected, feelingAfter: .energized,
                             locationContext: .oneOnOne, note: "Had coffee, talked for two hours. Felt really seen.")
        i1.sentimentLabel = .secure; i1.sentimentConfidence = 0.88
        let i2 = Interaction(interactionType: .text, initiator: .them,
                             feelingBefore: .neutral, feelingDuring: .connected, feelingAfter: .calm,
                             note: "Quick check-in, nothing major.")
        i2.sentimentLabel = .secure; i2.sentimentConfidence = 0.72
        let i3 = Interaction(interactionType: .call, initiator: .you,
                             feelingBefore: .anxious, feelingDuring: .anxious, feelingAfter: .drained,
                             note: "Felt like I was bothering them the whole time.")
        i3.sentimentLabel = .anxious; i3.sentimentConfidence = 0.91
        alex.interactions.append(contentsOf: [i1, i2, i3])

        // Interactions for Jordan
        let i4 = Interaction(interactionType: .inPerson, initiator: .them,
                             feelingBefore: .excited, feelingDuring: .authentic, feelingAfter: .satisfied,
                             note: "Great date.")
        i4.sentimentLabel = .secure; i4.sentimentConfidence = 0.95
        jordan.interactions.append(i4)

        // Pattern for Alex
        let p = Pattern(patternType: .initiationImbalance,
                        summary: "You initiate 78% of interactions with Alex",
                        detail: "Over the last 30 days you've reached out first in 7 of 9 non-unclear interactions. This is above the 65% threshold that typically indicates imbalance.",
                        severity: .medium, personName: "Alex Chen")
        ctx.insert(p)

        // Weekly digest
        let digest = WeeklyDigest(
            weekStartDate: Calendar.current.date(byAdding: .day, value: -7, to: .now)!,
            narrativeParagraph: "A relatively active social week. You had meaningful in-person time with Alex and a good date with Jordan. Your initiation rate with Alex is worth watching — you're carrying most of the conversational load.",
            initiationChanges: [
                InitiationChange(personName: "Alex Chen", previousRatio: 0.6, currentRatio: 0.78),
                InitiationChange(personName: "Jordan", previousRatio: 0.4, currentRatio: 0.3)
            ]
        )
        let dp = Pattern(patternType: .perceptionMismatch,
                         summary: "You feel anxious before seeing Alex but connected during",
                         detail: "In 4 of 5 interactions you logged Anxious before, but Connected or Authentic during. The anxiety is anticipatory, not reflective of the actual relationship.",
                         severity: .high)
        digest.patterns.append(dp)
        ctx.insert(digest)

        return container
    }

    // Convenience: a single Person pulled from the container
    static func person(in container: ModelContainer) -> Person {
        try! container.mainContext.fetch(FetchDescriptor<Person>()).first!
    }

    static func digest(in container: ModelContainer) -> WeeklyDigest {
        try! container.mainContext.fetch(FetchDescriptor<WeeklyDigest>()).first!
    }
}
