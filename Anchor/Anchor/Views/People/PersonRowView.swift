import SwiftUI

struct PersonRowView: View {
    let person: Person

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                AvatarView(person: person, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(person.name)
                            .font(.body)
                            .fontWeight(.medium)

                        RelationshipPill(type: person.relationshipType)
                    }

                    HStack(spacing: 4) {
                        if let days = person.daysSinceLastInteraction {
                            Text(days == 0 ? "Today" : "\(days)d ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No interactions yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(person.totalInteractions) interaction\(person.totalInteractions == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            InitiationRatioBar(ratio: person.initiationRatio, height: 5, showLabels: false)
                .padding(.leading, 50)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helpers

struct AvatarView: View {
    let person: Person
    let size: CGFloat

    var body: some View {
        Group {
            if let data = person.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(person.name.prefix(1).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(person.relationshipType.color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if let sentiment = person.dominantSentiment {
                Circle()
                    .strokeBorder(sentiment.color, lineWidth: 2.5)
            }
        }
    }
}

struct RelationshipPill: View {
    let type: RelationshipType

    var body: some View {
        Text(type.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(type.color.opacity(0.15))
            )
            .foregroundStyle(type.color)
    }
}
