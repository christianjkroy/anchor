import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingPage1().tag(0)
            OnboardingPage2().tag(1)
            OnboardingPage3(isComplete: $isComplete).tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

// MARK: - Page 1: What is Anchor

private struct OnboardingPage1: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AnchorColors.secure.opacity(0.15))
                    .frame(width: 160, height: 160)
                Image(systemName: "anchor")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(AnchorColors.secure)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Text("Know Your Relationships")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("You're probably wrong about how your relationships are going. Anchor shows you the data, not the story you've been telling yourself.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

// MARK: - Page 2: Track Fast

private struct OnboardingPage2: View {
    @State private var selectedFeeling: FeelingAfter = .calm
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "bolt.fill")
                .font(.system(size: 56))
                .foregroundStyle(AnchorColors.secure)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Text("Track in Under 30 Seconds")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Tap how you felt. Add a note if you want. That's it. The patterns emerge on their own.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Live demo pill selector
            VStack(alignment: .leading, spacing: 8) {
                Text("How did you feel after?")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FeelingAfter.allCases, id: \.self) { feeling in
                            PillButton(
                                label: feeling.rawValue,
                                isSelected: selectedFeeling == feeling,
                                color: feeling.color
                            ) {
                                HapticFeedback.light()
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedFeeling = feeling
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            .padding(.horizontal)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Page 3: The Full Picture

private struct OnboardingPage3: View {
    @Binding var isComplete: Bool
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Mock graph preview
                Circle().fill(AnchorColors.secure.opacity(0.2)).frame(width: 60, height: 60).offset(x: -60, y: -30)
                Circle().fill(AnchorColors.anxious.opacity(0.2)).frame(width: 44, height: 44).offset(x: 50, y: -50)
                Circle().fill(AnchorColors.neutral.opacity(0.2)).frame(width: 36, height: 36).offset(x: 70, y: 20)
                Circle().fill(AnchorColors.avoidant.opacity(0.2)).frame(width: 50, height: 50).offset(x: -40, y: 40)

                Circle().fill(AnchorColors.secure).frame(width: 24, height: 24).offset(x: -60, y: -30)
                Circle().fill(AnchorColors.anxious).frame(width: 18, height: 18).offset(x: 50, y: -50)
                Circle().fill(AnchorColors.neutral).frame(width: 14, height: 14).offset(x: 70, y: 20)
                Circle().fill(AnchorColors.avoidant).frame(width: 20, height: 20).offset(x: -40, y: 40)
            }
            .frame(width: 200, height: 180)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Text("See the Full Picture")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Every week, Anchor tells you what's actually true — who you're reaching out to, who's reaching out to you, and whether your feelings match reality.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                HapticFeedback.success()
                isComplete = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AnchorColors.secure)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .padding(.bottom, 48)
        }
        .padding()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

#Preview {
    @Previewable @State var done = false
    OnboardingView(isComplete: $done)
}
