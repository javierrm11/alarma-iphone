import SwiftUI
import AVFoundation
import Combine

/// Elegir el trozo de la canción arrastrando la onda, como la música de las historias de Instagram.
struct SongTrimmerView: View {
    let sourceURL: URL
    let title: String
    let artist: String
    var initialStart: Double = 0
    let onSave: (CustomSound) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var bars: [Float] = []
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var dragOrigin: Double?
    @State private var player: AVAudioPlayer?
    @State private var playing = false
    @State private var position: Double = 0
    @State private var loading = true
    @State private var saving = false
    @State private var errorText: String?

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var clipLength: Double { min(SongService.clipLength, max(1, duration)) }
    private var maxStart: Double { max(0, duration - clipLength) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                header

                if loading {
                    ProgressView("Leyendo la canción…")
                        .tint(Theme.primaryText)
                        .frame(height: 120)
                } else if bars.isEmpty {
                    Text(errorText ?? "No puedo leer la canción.")
                        .font(Theme.body(.body))
                        .foregroundStyle(Theme.primaryText)
                        .frame(height: 120)
                } else {
                    VStack(spacing: 10) {
                        Text("\(Fmt.mmss(Int(start))) – \(Fmt.mmss(Int(start + clipLength)))")
                            .font(Theme.clock(28))
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                        strip
                        Text("Arrastra la onda para elegir el trozo")
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.muted)
                    }

                    Button {
                        playing ? pause() : play(from: start)
                    } label: {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.onPrimary)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Theme.primary))
                            .background(Circle().fill(Theme.deep).offset(y: 4))
                    }
                    .accessibilityLabel(playing ? "Pausar" : "Reproducir el trozo")
                }

                Spacer(minLength: 0)

                if let errorText, !bars.isEmpty {
                    Text(errorText)
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.center)
                }

                Button {
                    save()
                } label: {
                    if saving {
                        ProgressView().tint(Theme.onPrimary)
                    } else {
                        Text("Usar este trozo")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(loading || saving || bars.isEmpty)
            }
            .padding(20)
            .screenBackground()
            .navigationTitle("Elige el trozo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.tint(Theme.primaryText)
                }
            }
        }
        .task { await load() }
        .onReceive(tick) { _ in loopCheck() }
        .onDisappear { player?.stop() }
        .interactiveDismissDisabled(saving)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.onPrimary)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.primary))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.display(.title3, .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                if !artist.isEmpty {
                    Text(artist)
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Onda arrastrable

    private var strip: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let windowWidth = width * 0.62
            let windowLeft = (width - windowWidth) / 2
            let pxPerSecond = windowWidth / CGFloat(clipLength)
            let offsetX = windowLeft - CGFloat(start) * pxPerSecond

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let step = pxPerSecond / CGFloat(SongService.barsPerSecond)
                    let barWidth = max(1.5, step * 0.62)
                    let maxHeight = size.height - 20
                    for (index, value) in bars.enumerated() {
                        let x = offsetX + CGFloat(index) * step
                        if x < -step || x > size.width { continue }
                        let time = Double(index) / SongService.barsPerSecond
                        let inside = time >= start && time < start + clipLength
                        let played = inside && playing && time < start + position
                        let height = max(4, CGFloat(value) * maxHeight)
                        let rect = CGRect(x: x, y: (size.height - height) / 2, width: barWidth, height: height)
                        let color = played ? Theme.deep : (inside ? Theme.primary : Theme.muted.opacity(0.35))
                        context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(color))
                    }
                }

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.text, lineWidth: 3)
                    .frame(width: windowWidth, height: geo.size.height)
                    .offset(x: windowLeft)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragOrigin == nil {
                            dragOrigin = start
                            pause()
                        }
                        let proposed = (dragOrigin ?? 0) - Double(value.translation.width / pxPerSecond)
                        start = min(max(0, proposed), maxStart)
                    }
                    .onEnded { _ in
                        dragOrigin = nil
                        play(from: start)
                    }
            )
        }
        .frame(height: 120)
        .accessibilityElement()
        .accessibilityLabel("Trozo de la canción")
        .accessibilityValue("De \(Fmt.mmss(Int(start))) a \(Fmt.mmss(Int(start + clipLength)))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: start = min(start + 5, maxStart)
            case .decrement: start = max(start - 5, 0)
            @unknown default: break
            }
        }
    }

    // MARK: Reproducción

    private func load() async {
        let url = sourceURL
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try SongService.waveform(of: url)
            }.value
            bars = result.bars
            duration = result.duration
            start = min(max(0, initialStart), max(0, result.duration - min(SongService.clipLength, result.duration)))
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.prepareToPlay()
            player = audio
            loading = false
            play(from: start)
        } catch {
            errorText = "No puedo leer la canción: \(error.localizedDescription)"
            loading = false
        }
    }

    private func play(from time: Double) {
        guard let player else { return }
        player.currentTime = time
        position = 0
        player.play()
        playing = true
    }

    private func pause() {
        player?.pause()
        playing = false
    }

    private func loopCheck() {
        guard let player, playing else { return }
        position = max(0, player.currentTime - start)
        if player.currentTime >= start + clipLength || !player.isPlaying {
            player.currentTime = start
            position = 0
            player.play()
        }
    }

    private func save() {
        pause()
        saving = true
        errorText = nil
        let url = sourceURL
        let clipStart = start
        let length = clipLength
        Task {
            do {
                let name = try await Task.detached(priority: .userInitiated) {
                    try SongService.exportClip(from: url, start: clipStart, length: length)
                }.value
                onSave(CustomSound(fileName: name, title: title, artist: artist, start: clipStart,
                                   length: length, originalFile: url.lastPathComponent))
                dismiss()
            } catch {
                errorText = "No he podido guardar el trozo: \(error.localizedDescription)"
                saving = false
            }
        }
    }
}
