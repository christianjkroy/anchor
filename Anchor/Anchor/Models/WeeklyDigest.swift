import Foundation
import SwiftData

@Model
final class WeeklyDigest {
    var id: UUID
    var generatedAt: Date
    var weekStartDate: Date
    var narrativeParagraph: String
    var initiationChangesData: Data
    var isRead: Bool

    @Relationship(deleteRule: .cascade)
    var patterns: [Pattern] = []

    init(
        id: UUID = .init(),
        generatedAt: Date = .now,
        weekStartDate: Date,
        narrativeParagraph: String,
        initiationChanges: [InitiationChange]
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.weekStartDate = weekStartDate
        self.narrativeParagraph = narrativeParagraph
        self.initiationChangesData = (try? JSONEncoder().encode(initiationChanges)) ?? Data()
        self.isRead = false
    }

    var initiationChanges: [InitiationChange] {
        (try? JSONDecoder().decode([InitiationChange].self, from: initiationChangesData)) ?? []
    }

    var weekDateRangeString: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStartDate) ?? weekStartDate
        return "\(df.string(from: weekStartDate)) – \(df.string(from: end))"
    }
}
