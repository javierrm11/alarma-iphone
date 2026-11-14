import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var permissions = Permissions()

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PipoView(mood: model.alarmAuth == .authorized ? .happy : .sleeping, size: 150)
                    .padding(.top, 24)
                Text("Hola, soy Pipo")
                    .font(Theme.display(.largeTitle, .semibold))
                    .foregroundStyle(Theme.text)
                Text("Voy a despertarte cada mañana. Para apagar la alarma tendrás que hacer un reto: andar, escanear un código, hacer cuentas o una foto. Si no lo haces, vuelvo a sonar.")
                    .font(Theme.body(.body))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    step("alarm.fill", "Alarmas", "Para sonar aunque el móvil esté en silencio",
                         done: model.alarmAuth == .authorized) {
                        Task { await model.requestAlarmAuthorization() }
                    }
                    step("figure.walk", "Movimiento", "Para contar tus pasos",
                         done: permissions.motion == .granted) {
                        permissions.requestMotion()
                    }
                    step("camera.fill", "Cámara", "Para escanear y hacer fotos",
                         done: permissions.camera == .granted) {
                        Task { await permissions.requestCamera() }
                    }
                    step("bell.badge.fill", "Avisos", "Para recordarte renovar la app",
                         done: permissions.notifications == .granted) {
                        Task { await permissions.requestNotifications() }
                    }
                }

                Button("Empezar") {
                    model.state.onboardingDone = true
                    model.save()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.alarmAuth != .authorized)

                if model.alarmAuth != .authorized {
                    Text("Como mínimo necesito el permiso de Alarmas.")
                        .font(Theme.body(.caption))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(20)
        }
        .screenBackground()
        .task { await permissions.refresh() }
    }

    private func step(_ icon: String, _ title: String, _ text: String, done: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.primaryText)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.body(.body, .bold)).foregroundStyle(Theme.text)
                Text(text).font(Theme.body(.caption)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                    .accessibilityLabel("Concedido")
            } else {
                Button("Permitir", action: action)
                    .font(Theme.body(.footnote, .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    .foregroundStyle(Theme.onPrimary)
            }
        }
        .padding(12)
        .pipoCard(radius: Theme.smallRadius)
    }
}
