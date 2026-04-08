import SwiftUI
import SwiftData

struct AddPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var relationshipType: RelationshipType = .friend
    @State private var selectedPhoto: UIImage?
    @State private var showImagePicker = false

    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showImagePicker = true
                        } label: {
                            if let photo = selectedPhoto {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemGray5))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("Their name", text: $name)
                }

                Section("Relationship") {
                    PillSelector(
                        title: "Type",
                        selection: $relationshipType,
                        pillColor: { $0.color }
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            }
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedPhoto)
            }
        }
    }

    private func save() {
        let person = Person(
            name: name.trimmingCharacters(in: .whitespaces),
            relationshipType: relationshipType
        )
        if let photo = selectedPhoto {
            person.photoData = photo.jpegData(compressionQuality: 0.8)
        }
        modelContext.insert(person)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Image Picker wrapper

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.dismiss()
        }
    }
}

#Preview {
    AddPersonView()
        .modelContainer(PreviewData.container())
}
