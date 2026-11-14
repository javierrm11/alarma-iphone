import SwiftUI

struct PhotoChallengeView: View {
    let header: ChallengeHeader
    let onDone: () -> Void
    let onFallback: () -> Void

    @Environment(AppModel.self) private var model
    @State private var reference: UIImage? = PhotoMatcher.loadReference()
    @State private var showCamera = false
    @State private var checking = false
    @State private var message: String?
    @State private var done = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if let reference {
                    Image(uiImage: reference)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 320)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            Chip(text: "Tu foto de referencia", fill: .white)
                                .padding(12)
                        }
                        .accessibilityLabel("Foto de referencia")
                }

                HStack(alignment: .center, spacing: 10) {
                    PipoView(mood: done ? .happy : .awake, accessory: model.state.equipped, size: 72)
                    SpeechBubble(text: message ?? "Ve a ese sitio y haz una foto igual, desde el mismo ángulo.")
                }

                if checking {
                    ProgressView("Comparando…")
                        .tint(Theme.primaryText)
                }

                Button {
                    showCamera = true
                } label: {
                    Label("Hacer la foto", systemImage: "camera.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(checking || done)

                Button("No puedo hacerla", action: onFallback)
                    .buttonStyle(GhostButtonStyle())
                Text("Si no puedes, el reto cambia a 10 cuentas.")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.muted)
            }
            .padding(20)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in compare(image) }
                .ignoresSafeArea()
        }
        .sensoryFeedback(.success, trigger: done)
    }

    private func compare(_ photo: UIImage) {
        guard let reference else { onFallback(); return }
        checking = true
        let threshold = Float(model.state.photoThreshold)
        Task.detached(priority: .userInitiated) {
            let distance = PhotoMatcher.distance(reference, photo)
            await MainActor.run {
                checking = false
                guard let distance else {
                    message = "No he podido comparar la foto. Prueba otra vez."
                    return
                }
                if distance <= threshold {
                    done = true
                    message = "¡Es igual! Muy bien."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDone() }
                } else {
                    message = String(format: "No se parece lo suficiente (%.2f, necesito %.2f o menos). Acércate más al sitio.", distance, threshold)
                }
            }
        }
    }
}

/// Cámara del sistema (o la fototeca si no hay cámara).
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
