import SwiftUI

/// Pantalla 6: comprobación unos minutos después del reto.
struct AwakeCheckView: View {
    let checkID: UUID

    @Environment(AppModel.self) private var model
    @State private var openedAt = Date()
    @State private var confirmed = false

    private let total: Double = 60

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, total - context.date.timeIntervalSince(openedAt))
            VStack(spacing: 22) {
                Spacer(minLength: 0)
                PipoView(mood: confirmed ? .happy : .suspicious, accessory: model.state.equipped, size: 140)

                RingView(progress: remaining / total, lineWidth: 14, color: Theme.accent) {
                    VStack(spacing: 2) {
                        Text(Fmt.mmss(Int(remaining.rounded(.up))))
                            .font(Theme.clock(40))
                            .foregroundStyle(Theme.text)
                        Text("para responder")
                            .font(Theme.body(.footnote))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 190, height: 190)

                VStack(spacing: 10) {
                    Text("¿Sigues ahí?")
                        .font(Theme.display(.largeTitle, .semibold))
                        .foregroundStyle(Theme.text)
                    Text(remaining > 0
                         ? "¿Seguro que no te has vuelto a tumbar? Si no respondes, Pipo vuelve a gritar."
                         : "Se acabó el tiempo. La alarma va a volver a sonar enseguida.")
                        .font(Theme.body(.body))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }

                Button {
                    confirmed = true
                    model.confirmCheck(checkID)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { model.route = nil }
                } label: {
                    Label("¡Sí, estoy despierto!", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(confirmed)

                if let next = model.nextCheckFire(checkID) {
                    Text("Si no, vuelvo a sonar a las \(Fmt.time(next)).")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .screenBackground()
        .onAppear {
            openedAt = Date()
            model.startCheck(checkID)
        }
        .sensoryFeedback(.success, trigger: confirmed)
        .interactiveDismissDisabled()
    }
}
