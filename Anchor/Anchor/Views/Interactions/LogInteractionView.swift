import SwiftUI
import SwiftData

struct LogInteractionView: View {
    let person: Person
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var interactionType: InteractionType = .inPerson
    @State private var initiator: Initiator = .you
    @State private var feelingBefore: FeelingBefore = .neutral
    @State private var feelingDuring: FeelingDuring = .connected
    @State private var feelingAfter: FeelingAfter = .calm
    @State private var locationContext: LocationContext? = nil
    @State private var note = ""
    @State private var durationText = ""
    @State private var micPermissionGranted = false
    @StateObject private var speech = SpeechRecognizer()

    private let noteLimit = 500

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    loggingIntroCard

                    formCard(title: "Interaction Basics", subtitle: "Capture what happened and who carried the momentum.") {
                        PillSelector(title: "How did you interact?",
                                     selection: $interactionType)

                        PillSelector(title: "Who initiated?",
                                     selection: $initiator)
                    }

                    formCard(title: "Emotional Arc", subtitle: "Describe the emotional shift from before to after.") {
                        PillSelector(title: "How did you feel before?",
                                     selection: $feelingBefore,
                                     pillColor: { $0.color })

                        PillSelector(title: "How did you feel during?",
                                     selection: $feelingDuring,
                                     pillColor: { $0.color })

                        PillSelector(title: "How did you feel after?",
                                     selection: $feelingAfter,
                                     pillColor: { $0.color })
                    }

                    formCard(title: "Context", subtitle: "Add optional detail if it helps explain the dynamic.") {
                        OptionalPillSelector(title: "Setting",
                                            selection: $locationContext)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reflection")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    Task { await toggleVoice() }
                                } label: {
                                    Label(speech.isRecording ? "Stop" : "Dictate", systemImage: speech.isRecording ? "stop.circle.fill" : "mic.circle")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill((speech.isRecording ? AnchorColors.anxious : AnchorColors.secure).opacity(0.12)))
                                        .foregroundStyle(speech.isRecording ? AnchorColors.anxious : AnchorColors.secure)
                                        .symbolEffect(.pulse, isActive: speech.isRecording)
                                }
                                .accessibilityLabel(speech.isRecording ? "Stop recording" : "Dictate note")
                            }

                            ZStack(alignment: .topLeading) {
                                if note.isEmpty && !speech.isRecording {
                                    Text("What stood out? What did you notice about the energy, effort, or vibe?")
                                        .foregroundStyle(Color(.placeholderText))
                                        .padding(8)
                                        .allowsHitTesting(false)
                                }
                                if speech.isRecording {
                                    Text(speech.transcript.isEmpty ? "Listening…" : speech.transcript)
                                        .foregroundStyle(speech.transcript.isEmpty ? Color(.placeholderText) : .primary)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                } else {
                                    TextEditor(text: $note)
                                        .frame(minHeight: 110)
                                        .onChange(of: note) { _, new in
                                            if new.count > noteLimit {
                                                note = String(new.prefix(noteLimit))
                                            }
                                        }
                                }
                            }
                            .font(.body)
                            .padding(4)
                            .frame(minHeight: 110)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(speech.isRecording
                                          ? AnchorColors.anxious.opacity(0.06)
                                          : Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(speech.isRecording ? AnchorColors.anxious.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                            )

                            HStack {
                                if let err = speech.errorMessage {
                                    Text(err)
                                        .font(.caption2)
                                        .foregroundStyle(AnchorColors.anxious)
                                } else {
                                    Text("Notes help the weekly digest and pattern detection feel sharper.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(note.count)/\(noteLimit)")
                                    .font(.caption2)
                                    .foregroundStyle(note.count > noteLimit - 50 ? AnchorColors.anxious : .secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            HStack {
                                TextField("Minutes", text: $durationText)
                                    .keyboardType(.numberPad)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                    )
                                    .frame(width: 110)
                                Text("minutes")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log Interaction")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { speech.stopRecording() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var loggingIntroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Logging for \(person.name)")
                .font(.headline)
            Text("Capture the tone of the interaction while it’s still fresh. The app will use this to track patterns over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(.secondarySystemGroupedBackground), AnchorColors.secure.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func formCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func toggleVoice() async {
        if speech.isRecording {
            speech.stopRecording()
            // Append transcript to note
            let transcribed = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcribed.isEmpty {
                note = note.isEmpty ? transcribed : note + " " + transcribed
                speech.transcript = ""
            }
        } else {
            if !micPermissionGranted {
                micPermissionGranted = await speech.requestPermission()
                guard micPermissionGranted else {
                    speech.errorMessage = "Microphone or speech access denied. Enable in Settings."
                    return
                }
            }
            speech.transcript = ""
            speech.startRecording()
        }
    }

    private func save() {
        let interaction = Interaction(
            interactionType: interactionType,
            initiator: initiator,
            durationMinutes: Int(durationText),
            feelingBefore: feelingBefore,
            feelingDuring: feelingDuring,
            feelingAfter: feelingAfter,
            locationContext: locationContext,
            note: note
        )
        person.interactions.append(interaction)
        HapticFeedback.medium()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()

        // Snapshot enum values before the async boundary
        let iType         = interactionType.backendValue
        let iInitiatedBy  = initiator.backendValue
        let iBefore       = feelingBefore.rawValue.lowercased()
        let iDuring       = feelingDuring.rawValue.lowercased()
        let iAfter        = feelingAfter.rawValue.lowercased()
        let iLocation     = locationContext?.rawValue.lowercased()
        let iDuration     = Int(durationText)
        let iNote         = note

        // Classify sentiment and sync to backend
        Task { @MainActor in
            try? await LocalAnalysisService.shared.classifyPendingSentiments(for: person, context: modelContext)

            // Ensure person is synced first
            if person.backendId == nil {
                let pid = await AnchorAPIService.shared.syncPerson(
                    name: person.name,
                    relationshipType: person.relationshipType.rawValue.lowercased()
                )
                if let pid {
                    person.backendId = pid
                    try? modelContext.save()
                }
            }

            guard let backendPersonId = person.backendId else { return }
            let backendId = await AnchorAPIService.shared.syncInteraction(
                backendPersonId: backendPersonId,
                type: iType,
                initiatedBy: iInitiatedBy,
                feelingBefore: iBefore,
                feelingDuring: iDuring,
                feelingAfter: iAfter,
                locationContext: iLocation,
                durationMinutes: iDuration,
                note: iNote
            )
            if let backendId {
                interaction.backendId = backendId
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    let container = PreviewData.container()
    let person = PreviewData.person(in: container)
    return LogInteractionView(person: person)
        .modelContainer(container)
}
