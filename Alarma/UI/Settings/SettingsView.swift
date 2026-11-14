import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var permissions = Permissions()
    @State private var testScheduled = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenTitle("Ajustes")
                    SoundCard()
                    permissionsCard
                    signingCard
                    testCard
                    logCard
                    Text("Pipo \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · hecho para ti")
                        .font(Theme.body(.caption))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task { await permissions.refresh() }
        }
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Permisos")
            VStack(spacing: 0) {
                permissionRow("Alarmas", "Imprescindible para que suene",
                              status: alarmStatus) {
                    if model.alarmAuth == .denied { Permissions.openSettings() } else {
                        Task { await model.requestAlarmAuthorization() }
                    }
                }
                CardDivider()
                permissionRow("Movimiento", "Para el reto de pasos", status: permissions.motion) {
                    if permissions.motion == .denied { Permissions.openSettings() } else { permissions.requestMotion() }
                }
                CardDivider()
                permissionRow("Cámara", "Para escanear y las fotos", status: permissions.camera) {
                    if permissions.camera == .denied { Permissions.openSettings() } else {
                        Task { await permissions.requestCamera() }
                    }
                }
                CardDivider()
                permissionRow("Avisos", "Para recordarte renovar la app", status: permissions.notifications) {
                    if permissions.notifications == .denied { Permissions.openSettings() } else {
                        Task { await permissions.requestNotifications() }
                    }
                }
            }
            .pipoCard()
        }
    }

    private var alarmStatus: PermissionStatus {
        switch model.alarmAuth {
        case .authorized: return .granted
        case .denied: return .denied
        default: return .notAsked
        }
    }

    private func permissionRow(_ title: String, _ subtitle: String, status: PermissionStatus, action: @escaping () -> Void) -> some View {
        InfoRow(title: title, subtitle: subtitle) {
            if status == .granted {
                Label("Permitido", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(Theme.body(.footnote, .bold))
                    .foregroundStyle(Theme.primaryText)
            } else {
                Button(status == .denied ? "Abrir Ajustes" : "Permitir", action: action)
                    .font(Theme.body(.footnote, .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    .foregroundStyle(Theme.onPrimary)
            }
        }
        .padding(.vertical, 4)
    }

    private var signingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Firma de la app")
            VStack(alignment: .leading, spacing: 6) {
                if let expiry = model.signingExpiry {
                    Text(expiry > Date() ? "Caduca el \(Fmt.shortDateTime(expiry))" : "Caducó el \(Fmt.shortDateTime(expiry))")
                        .font(Theme.body(.body, .bold))
                        .foregroundStyle(expiry.timeIntervalSinceNow < 2 * 86400 ? Theme.primaryText : Theme.text)
                    Text(expiry > Date() ? "Quedan \(Fmt.until(expiry)). Renuévala en SideStore antes: si caduca, la alarma no suena. Te aviso 2 días antes."
                         : "Renueva la app en SideStore ahora mismo.")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("No encuentro el perfil de firma")
                        .font(Theme.body(.body, .bold))
                        .foregroundStyle(Theme.text)
                    Text("Es normal si la instalaste de otra forma. Con SideStore o Sideloadly aparece aquí la fecha.")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pipoCard()
        }
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Pruebas")
            VStack(alignment: .leading, spacing: 12) {
                Text("Programa una alarma dentro de 1 minuto con 20 pasos y 3 respaldos. Bloquea el móvil y espera.")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.muted)
                Button(testScheduled ? "Programada: bloquea el móvil" : "Probar alarma en 1 minuto") {
                    model.scheduleTest()
                    testScheduled = true
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(testScheduled || model.alarmAuth != .authorized)
                Button("Reprogramar todas las alarmas") {
                    Task { await model.reconcile() }
                }
                .buttonStyle(GhostButtonStyle())
                Text("Alarmas programadas en el sistema: \(model.futureScheduledCount)")
                    .font(Theme.body(.caption))
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            .pipoCard()
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Registro")
            VStack(alignment: .leading, spacing: 6) {
                if model.state.events.isEmpty {
                    Text("Todavía no ha pasado nada.")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                }
                ForEach(Array(model.state.events.prefix(30).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .pipoCard()
        }
    }
}
