import SwiftUI
import MediaPlayer
import UniformTypeIdentifiers

/// Tarjeta de Ajustes para elegir la canción de la alarma.
struct SoundCard: View {
    @Environment(AppModel.self) private var model
    @State private var showMusic = false
    @State private var showFiles = false
    @State private var trimming: TrimRequest?
    @State private var busy = false
    @State private var errorText: String?

    struct TrimRequest: Identifiable {
        let id = UUID()
        let url: URL
        let title: String
        let artist: String
        let start: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Sonido de la alarma")
            VStack(alignment: .leading, spacing: 12) {
                current

                if busy {
                    ProgressView("Copiando la canción…")
                        .tint(Theme.primaryText)
                }
                if let errorText {
                    Text(errorText)
                        .font(Theme.body(.subheadline, .semibold))
                        .foregroundStyle(Theme.primaryText)
                }

                HStack(spacing: 10) {
                    Button {
                        openMusic()
                    } label: {
                        Label("De Música", systemImage: "music.note.list")
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button {
                        errorText = nil
                        showFiles = true
                    } label: {
                        Label("De Archivos", systemImage: "folder")
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .disabled(busy)

                if let sound = model.state.customSound {
                    let original = SongService.originalURL(named: sound.originalFile)
                    if FileManager.default.fileExists(atPath: original.path) {
                        Button("Cambiar el trozo") {
                            trimming = TrimRequest(url: original, title: sound.title, artist: sound.artist, start: sound.start)
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                    Button("Volver al sonido del sistema") {
                        SongService.removeClips()
                        model.setCustomSound(nil)
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Text("Solo valen canciones compradas (iTunes Store) o archivos tuyos; las de Apple Music o Spotify están protegidas. Pruébalo con \"Probar alarma en 1 minuto\": si suena el sonido normal, iOS no admite canciones en las alarmas.")
                    .font(Theme.body(.caption))
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pipoCard()
        }
        .sheet(isPresented: $showMusic) {
            MusicPicker { item in importItem(item) }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                do {
                    let local = try SongService.importFromFile(url)
                    trimming = TrimRequest(url: local, title: url.deletingPathExtension().lastPathComponent, artist: "", start: 0)
                } catch {
                    errorText = error.localizedDescription
                }
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
        .sheet(item: $trimming) { request in
            SongTrimmerView(sourceURL: request.url, title: request.title, artist: request.artist,
                            initialStart: request.start) { sound in
                model.setCustomSound(sound)
            }
        }
    }

    @ViewBuilder
    private var current: some View {
        HStack(spacing: 12) {
            Image(systemName: model.state.customSound == nil ? "alarm.waves.left.and.right" : "music.note")
                .font(.title3)
                .foregroundStyle(Theme.primaryText)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
            VStack(alignment: .leading, spacing: 2) {
                if let sound = model.state.customSound {
                    Text(sound.title)
                        .font(Theme.body(.body, .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text([sound.artist, "trozo \(sound.rangeText)"].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("Sonido de alarma del sistema")
                        .font(Theme.body(.body, .bold))
                        .foregroundStyle(Theme.text)
                    Text("Elige una canción para despertarte")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func openMusic() {
        errorText = nil
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    showMusic = true
                } else {
                    errorText = "Pipo no tiene permiso para ver tu música. Actívalo en Ajustes > Pipo > Contenido multimedia y Apple Music."
                }
            }
        }
    }

    private func importItem(_ item: MPMediaItem) {
        busy = true
        errorText = nil
        let title = item.title ?? "Canción"
        let artist = item.artist ?? ""
        Task {
            do {
                let url = try await SongService.importFromLibrary(item)
                busy = false
                // Esperar a que se cierre el selector antes de abrir el recorte.
                try? await Task.sleep(for: .milliseconds(500))
                trimming = TrimRequest(url: url, title: title, artist: artist, start: 0)
            } catch {
                busy = false
                errorText = error.localizedDescription
            }
        }
    }
}

/// Selector de canciones de la biblioteca de Música.
struct MusicPicker: UIViewControllerRepresentable {
    let onPick: (MPMediaItem) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = false
        picker.showsItemsWithProtectedAssets = false
        picker.prompt = "Elige la canción de la alarma"
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let parent: MusicPicker

        init(_ parent: MusicPicker) {
            self.parent = parent
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            if let item = mediaItemCollection.items.first {
                parent.onPick(item)
            }
            parent.dismiss()
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            parent.dismiss()
        }
    }
}
