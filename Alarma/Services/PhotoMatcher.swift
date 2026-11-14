import UIKit
import Vision

/// Compara dos fotos con Vision (huella de imagen). Cuanto menor la distancia, más se parecen.
enum PhotoMatcher {
    static func featurePrint(_ image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.downscaled(maxSide: 1024).cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        return request.results?.first
    }

    static func distance(_ a: UIImage, _ b: UIImage) -> Float? {
        guard let fa = featurePrint(a), let fb = featurePrint(b) else { return nil }
        var d: Float = 0
        do {
            try fa.computeDistance(&d, to: fb)
            return d
        } catch {
            return nil
        }
    }

    static func loadReference() -> UIImage? {
        guard let data = try? Data(contentsOf: Persistence.referencePhotoURL) else { return nil }
        return UIImage(data: data)
    }

    static func saveReference(_ image: UIImage) {
        try? FileManager.default.createDirectory(at: Persistence.folder, withIntermediateDirectories: true)
        if let data = image.downscaled(maxSide: 1600).jpegData(compressionQuality: 0.8) {
            try? data.write(to: Persistence.referencePhotoURL, options: .atomic)
        }
    }
}

extension UIImage {
    /// Redibuja la imagen en orientación normal y como mucho `maxSide` píxeles de lado.
    func downscaled(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
