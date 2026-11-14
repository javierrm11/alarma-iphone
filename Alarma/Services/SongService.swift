import Foundation
import AVFoundation
import MediaPlayer

/// Canción elegida para la alarma: un trozo recortado y guardado en Library/Sounds.
struct CustomSound: Codable, Hashable {
    var fileName: String
    var title: String
    var artist: String
    var start: Double
    var length: Double
    /// Copia de la canción entera, para poder cambiar el trozo después.
    var originalFile: String

    var rangeText: String {
        "\(Fmt.mmss(Int(start))) – \(Fmt.mmss(Int(start + length)))"
    }
}

enum SongError: LocalizedError {
    case protected, exportFailed, unreadable

    var errorDescription: String? {
        switch self {
        case .protected:
            return "Esa canción está protegida (Apple Music o solo en la nube). Usa una comprada en iTunes Store y descargada en el iPhone."
        case .exportFailed:
            return "No he podido copiar la canción."
        case .unreadable:
            return "No puedo leer ese archivo de audio."
        }
    }
}

enum SongService {
    /// Duración del trozo (los sonidos de aviso de iOS suelen limitarse a 30 s).
    static let clipLength: Double = 30
    static let barsPerSecond: Double = 2

    static var soundsFolder: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    static func originalURL(named name: String) -> URL {
        Persistence.folder.appendingPathComponent(name)
    }

    private static func prepareFolders() {
        try? FileManager.default.createDirectory(at: Persistence.folder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: soundsFolder, withIntermediateDirectories: true)
    }

    private static func removeOriginals() {
        let files = (try? FileManager.default.contentsOfDirectory(at: Persistence.folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("cancion-original") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func removeClips() {
        let files = (try? FileManager.default.contentsOfDirectory(at: soundsFolder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("pipo-cancion") {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func clipExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: soundsFolder.appendingPathComponent(name).path)
    }

    // MARK: Importar

    /// Copia una canción de la biblioteca de Música (solo compradas, sin protección).
    static func importFromLibrary(_ item: MPMediaItem) async throws -> URL {
        guard let assetURL = item.assetURL, !item.hasProtectedAsset else { throw SongError.protected }
        prepareFolders()
        removeOriginals()
        let destination = originalURL(named: "cancion-original-\(Int(Date().timeIntervalSince1970)).m4a")
        let asset = AVURLAsset(url: assetURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw SongError.exportFailed
        }
        try await session.export(to: destination, as: .m4a)
        return destination
    }

    /// Copia un archivo de audio elegido en la app Archivos.
    static func importFromFile(_ url: URL) throws -> URL {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        prepareFolders()
        removeOriginals()
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased()
        let destination = originalURL(named: "cancion-original-\(Int(Date().timeIntervalSince1970)).\(ext)")
        try FileManager.default.copyItem(at: url, to: destination)
        do {
            _ = try AVAudioFile(forReading: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw SongError.unreadable
        }
        return destination
    }

    // MARK: Onda

    /// Volumen medio de cada medio segundo de la canción, entre 0 y 1.
    static func waveform(of url: URL) throws -> (bars: [Float], duration: Double) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = file.length
        let duration = Double(totalFrames) / format.sampleRate
        let barCount = max(1, Int(duration * barsPerSecond))
        let framesPerBar = AVAudioFrameCount(max(1, totalFrames / Int64(barCount)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerBar) else {
            throw SongError.unreadable
        }

        var values: [Float] = []
        values.reserveCapacity(barCount)
        for _ in 0..<barCount {
            try file.read(into: buffer, frameCount: framesPerBar)
            let frames = Int(buffer.frameLength)
            guard frames > 0, let channel = buffer.floatChannelData?[0] else { break }
            var sum: Float = 0
            var count = 0
            var index = 0
            while index < frames {
                let sample = channel[index]
                sum += sample * sample
                count += 1
                index += 16
            }
            values.append(sqrt(sum / Float(max(1, count))))
        }
        let peak = values.max() ?? 1
        let normalized = values.map { peak > 0 ? min(1, $0 / peak) : 0 }
        return (normalized, duration)
    }

    // MARK: Recortar

    /// Guarda el trozo elegido como .caf en Library/Sounds y devuelve su nombre de archivo.
    static func exportClip(from source: URL, start: Double, length: Double) throws -> String {
        prepareFolders()
        removeClips()
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let sampleRate = format.sampleRate
        let startFrame = AVAudioFramePosition(max(0, start) * sampleRate)
        guard startFrame < input.length else { throw SongError.unreadable }
        let available = Double(input.length - startFrame)
        let frames = AVAudioFrameCount(min(available, length * sampleRate))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw SongError.unreadable
        }
        input.framePosition = startFrame
        try input.read(into: buffer, frameCount: frames)

        // Entrada y salida suaves (0,08 s) para que no haga "clic" al repetirse.
        if let channels = buffer.floatChannelData {
            let count = Int(buffer.frameLength)
            let fade = min(count / 4, Int(0.08 * sampleRate))
            if fade > 0 {
                for c in 0..<Int(format.channelCount) {
                    let data = channels[c]
                    for i in 0..<fade {
                        let gain = Float(i) / Float(fade)
                        data[i] *= gain
                        data[count - 1 - i] *= gain
                    }
                }
            }
        }

        let name = "pipo-cancion-\(Int(Date().timeIntervalSince1970)).caf"
        let destination = soundsFolder.appendingPathComponent(name)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        do {
            let output = try AVAudioFile(forWriting: destination, settings: settings,
                                         commonFormat: .pcmFormatFloat32, interleaved: false)
            try output.write(from: buffer)
        }
        return name
    }
}
