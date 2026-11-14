import SwiftUI
import VisionKit

/// Pestaña Retos: preparar el código a escanear y la foto de referencia.
struct ChallengesView: View {
    @Environment(AppModel.self) private var model
    @State private var registering = false
    @State private var takingReference = false
    @State private var testingPhoto = false
    @State private var reference: UIImage? = PhotoMatcher.loadReference()
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenTitle("Retos")
                    HStack(alignment: .bottom, spacing: 10) {
                        PipoView(mood: .awake, accessory: model.state.equipped, size: 80)
                        SpeechBubble(text: "Lo que más despierta es moverse y cambiar de habitación. Prepara aquí los retos.")
                    }
                    scanCard
                    photoCard
                    infoCard(icon: "figure.walk", title: "Pasos",
                             text: "Solo cuentan los pasos dados después de que suene. Si te paras \(StepCounter.idleLimit) s, el contador baja \(StepCounter.penaltySteps).")
                    infoCard(icon: "plus.forwardslash.minus", title: "Cuentas",
                             text: "Sumas, restas y multiplicaciones. Si fallas, sale otra.")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $registering) {
                RegisterCodeView()
            }
            .fullScreenCover(isPresented: $takingReference) {
                CameraPicker { image in
                    PhotoMatcher.saveReference(image)
                    reference = PhotoMatcher.loadReference()
                    testResult = nil
                    model.log("Foto de referencia guardada")
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $testingPhoto) {
                CameraPicker { image in test(image) }
                    .ignoresSafeArea()
            }
        }
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle(icon: "barcode.viewfinder", title: "Escanear un código")
            if let code = model.state.savedCode {
                Text(code.name)
                    .font(Theme.body(.title3, .bold))
                    .foregroundStyle(Theme.text)
                Text(code.payload)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("Registra el código de barras de algo que esté lejos de la cama: la pasta de dientes, la cafetera… Solo valdrá ese.")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.muted)
            }
            Button(model.state.savedCode == nil ? "Registrar código" : "Cambiar código") { registering = true }
                .buttonStyle(GhostButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pipoCard()
    }

    private var photoCard: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            cardTitle(icon: "camera", title: "Foto de un sitio")
            if let reference {
                Image(uiImage: reference)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                    .accessibilityLabel("Foto de referencia")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exigencia al comparar")
                        .font(Theme.body(.subheadline, .semibold))
                        .foregroundStyle(Theme.text)
                    Slider(value: $model.state.photoThreshold, in: 0.3...1.5, step: 0.05) {
                        Text("Exigencia")
                    } minimumValueLabel: {
                        Text("Más").font(Theme.body(.caption))
                    } maximumValueLabel: {
                        Text("Menos").font(Theme.body(.caption))
                    }
                    .tint(Theme.primary)
                    .onChange(of: model.state.photoThreshold) { _, _ in model.save() }
                    Text(String(format: "Vale si la diferencia es %.2f o menos.", model.state.photoThreshold))
                        .font(Theme.body(.caption))
                        .foregroundStyle(Theme.muted)
                }
                if let testResult {
                    Text(testResult)
                        .font(Theme.body(.subheadline, .semibold))
                        .foregroundStyle(Theme.primaryText)
                }
                HStack(spacing: 10) {
                    Button("Repetir foto") { takingReference = true }
                        .buttonStyle(GhostButtonStyle())
                    Button("Probar") { testingPhoto = true }
                        .buttonStyle(GhostButtonStyle())
                }
            } else {
                Text("Haz una foto de un sitio concreto (el lavabo, la nevera abierta). Para apagar la alarma tendrás que hacer otra igual.")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.muted)
                Button("Hacer foto de referencia") { takingReference = true }
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pipoCard()
    }

    private func test(_ photo: UIImage) {
        guard let reference else { return }
        testResult = "Comparando…"
        let threshold = model.state.photoThreshold
        Task.detached(priority: .userInitiated) {
            let distance = PhotoMatcher.distance(reference, photo)
            await MainActor.run {
                if let distance {
                    let ok = Double(distance) <= threshold
                    testResult = String(format: "Diferencia: %.2f · %@", distance, ok ? "valdría" : "no valdría")
                } else {
                    testResult = "No he podido comparar las fotos."
                }
            }
        }
    }

    private func cardTitle(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.primaryText)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
            Text(title)
                .font(Theme.display(.title3, .semibold))
                .foregroundStyle(Theme.text)
        }
    }

    private func infoCard(icon: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle(icon: icon, title: title)
            Text(text)
                .font(Theme.body(.subheadline))
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pipoCard()
    }
}

/// Escanea un código una vez y lo guarda con un nombre.
struct RegisterCodeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var payload: String?
    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let payload {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.primary)
                    Text("Código leído")
                        .font(Theme.display(.title2, .semibold))
                    Text(payload)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    TextField("¿Qué es? (pasta de dientes…)", text: $name)
                        .font(Theme.body(.body, .semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .pipoCard(radius: Theme.smallRadius)
                    Button("Guardar") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        model.state.savedCode = SavedCode(name: trimmed.isEmpty ? "Mi código" : trimmed, payload: payload)
                        model.log("Código del reto registrado")
                        model.save()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Escanear otro") { self.payload = nil }
                        .buttonStyle(GhostButtonStyle())
                    Spacer()
                } else if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    Text("Apunta al código de barras o QR")
                        .font(Theme.body(.body, .semibold))
                        .foregroundStyle(Theme.text)
                    BarcodeScannerView { code in
                        if payload == nil { payload = code }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                } else {
                    Text("La cámara no está disponible. Revisa el permiso de Cámara en Ajustes.")
                        .font(Theme.body(.body))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
            .padding(20)
            .screenBackground()
            .navigationTitle("Registrar código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.tint(Theme.primaryText)
                }
            }
        }
    }
}
