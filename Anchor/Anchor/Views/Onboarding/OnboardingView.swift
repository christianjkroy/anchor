import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 0.96),
                    Color(red: 0.92, green: 0.97, blue: 0.96),
                    Color(red: 0.96, green: 0.95, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingPage1().tag(0)
                OnboardingPage2().tag(1)
                OnboardingPage3(isComplete: $isComplete).tag(2)
            }
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
                RoundedRectangle(cornerRadius: 36)
                    .fill(.white.opacity(0.45))
                    .frame(width: 220, height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .strokeBorder(.white.opacity(0.6), lineWidth: 1)
                    )
                Circle()
                    .fill(AnchorColors.secure.opacity(0.12))
                    .frame(width: 170, height: 170)
                Circle()
                    .fill(AnchorColors.neutral.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .offset(x: 42, y: 36)
                Image(systemName: "anchor")
                    .font(.system(size: 76, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AnchorColors.secure, AnchorColors.neutral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Text("See your relationships more clearly")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Anchor helps you separate what actually happened from the story anxiety tells you after the fact.")
                    .font(.title3)
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
                Text("Track a moment while it’s still fresh")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Log the interaction, capture the emotional arc, and let the app build the pattern over time.")
                    .font(.title3)
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
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(.secondarySystemBackground).opacity(0.92))
            )
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
                Text("Get a fuller read on the dynamic")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Over time, Anchor shows who reaches out, how interactions actually feel, and where your perception matches the data.")
                    .font(.title3)
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
                    .background(
                        LinearGradient(
                            colors: [AnchorColors.secure, AnchorColors.neutral],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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
