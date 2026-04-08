import SwiftUI

struct PersonRowView: View {
    let person: Person

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(person.dominantSentiment?.color ?? person.relationshipType.color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 12)

            HStack(alignment: .center, spacing: 13) {
                AvatarView(person: person, size: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        RelationshipPill(type: person.relationshipType)
                        if let days = person.daysSinceLastInteraction {
                            Text(days == 0 ? "today" : "\(days)d ago")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    InitiationRatioBar(ratio: person.initiationRatio, height: 3, showLabels: false)
                        .frame(maxWidth: 120)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(person.totalInteractions)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(AnchorColors.secure)
                    Text("interactions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let sentiment = person.dominantSentiment {
                        Text(sentiment.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(sentiment.color.opacity(0.15)))
                            .foregroundStyle(sentiment.color)
                    }
                }
                .padding(.trailing, 14)
            }
            .padding(.vertical, 13)
            .padding(.leading, 11)
        }
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

#Preview {
    let container = PreviewData.container()
    let person = PreviewData.person(in: container)
    return List {
        PersonRowView(person: person)
    }
    .modelContainer(container)
}
