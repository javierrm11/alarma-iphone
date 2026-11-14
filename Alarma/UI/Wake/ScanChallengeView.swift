import SwiftUI
import VisionKit
import AVFoundation

struct ScanChallengeView: View {
    let header: ChallengeHeader
    let onDone: () -> Void
    let onFallback: () -> Void

    @Environment(AppModel.self) private var model
    @State private var message: String?
    @State private var torchOn = false
    @State private var done = false

    private var scannerReady: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Color(hex: 0x0B0B0D))
                    if scannerReady {
                        BarcodeScannerView { code in handle(code) }
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    } else {
                        Text("La cámara no está disponible. Revisa el permiso de Cámara en Ajustes.")
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(24)
                    }
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Theme.primary)
                    }
                }
                .frame(height: 380)

                HStack(spacing: 14) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title2)
                        .foregroundStyle(Theme.primaryText)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(Theme.surface2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.state.savedCode?.name ?? "Tu código")
                            .font(Theme.body(.body, .bold))
                            .foregroundStyle(Theme.text)
                        Text(message ?? "Solo vale este código.")
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(message == nil ? Theme.muted : Theme.primaryText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .pipoCard()

                HStack(spacing: 10) {
                    Button {
                        torchOn.toggle()
                        Torch.set(torchOn)
                    } label: {
                        Label(torchOn ? "Apagar linterna" : "Linterna", systemImage: "flashlight.on.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button("No lo encuentro", action: onFallback)
                        .buttonStyle(GhostButtonStyle())
                }
                Text("Si no lo encuentras, el reto cambia a 300 pasos.")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.muted)
            }
            .padding(20)
        }
        .onDisappear { Torch.set(false) }
        .sensoryFeedback(.success, trigger: done)
    }

    private func handle(_ code: String) {
        guard !done else { return }
        if code == model.state.savedCode?.payload {
            done = true
            Torch.set(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDone() }
        } else {
            message = "Ese no es. Busca \(model.state.savedCode?.name.lowercased() ?? "tu código")."
        }
    }
}

enum Torch {
    static func set(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }
}

/// Escáner de códigos de barras y QR de VisionKit.
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes: [.barcode()], isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        if !controller.isScanning {
            DispatchQueue.main.async { try? controller.startScanning() }
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    onCode(payload)
                }
            }
        }
    }
}
