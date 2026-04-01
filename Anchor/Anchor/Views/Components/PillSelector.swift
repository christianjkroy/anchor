import SwiftUI

// MARK: - Required pill selector (non-optional binding)

struct PillSelector<T: CaseIterable & Hashable & RawRepresentable>: View
    where T.RawValue == String, T.AllCases: RandomAccessCollection {

    let title: String
    @Binding var selection: T
    var pillColor: ((T) -> Color)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(T.allCases), id: \.self) { option in
                        PillButton(
                            label: option.rawValue,
                            isSelected: selection == option,
                            color: pillColor?(option) ?? .secondary
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selection = option
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Optional pill selector

struct OptionalPillSelector<T: CaseIterable & Hashable & RawRepresentable>: View
    where T.RawValue == String, T.AllCases: RandomAccessCollection {

    let title: String
    @Binding var selection: T?
    var pillColor: ((T) -> Color)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(T.allCases), id: \.self) { option in
                        PillButton(
                            label: option.rawValue,
                            isSelected: selection == option,
                            color: pillColor?(option) ?? .secondary
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selection = (selection == option) ? nil : option
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Shared pill button

struct PillButton: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? color.opacity(0.18) : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isSelected ? color : .clear, lineWidth: 1.5)
                )
                .foregroundStyle(isSelected ? color : Color(.secondaryLabel))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
