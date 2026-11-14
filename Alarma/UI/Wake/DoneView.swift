import SwiftUI

/// Pantalla 7: resumen de la mañana y recompensa.
struct DoneView: View {
    let record: WakeRecord
    let onClose: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    ConfettiDots()
                    PipoView(mood: .happy, accessory: model.newlyUnlocked ?? model.state.equipped ?? .hat, size: 170)
                }
                .frame(height: 190)

                VStack(spacing: 6) {
                    Text("¡Lo has conseguido!")
                        .font(Theme.display(.largeTitle, .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Despierto a las \(Fmt.time(record.completedAt ?? Date())) · alarma de las \(Fmt.time(record.occurrence))")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    stat(Fmt.mmss(record.challengeSeconds), "min de reto")
                    stat("\(record.backupsRung)", record.backupsRung == 1 ? "respaldo sonó" : "respaldos sonaron")
                    stat("\(model.currentStreak())", "días de racha")
                }

                if let unlocked = model.newlyUnlocked {
                    HStack(spacing: 12) {
                        PipoView(mood: .happy, accessory: unlocked, size: 52, animated: false)
                        VStack(alignment: .leading, spacing: 2) {
                            SectionLabel("Nuevo accesorio", color: Theme.primaryText)
                            Text("\(unlocked.name) para Pipo")
                                .font(Theme.body(.body, .bold))
                                .foregroundStyle(Theme.text)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .pipoCard()
                }

                if !model.state.nightMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel("Tu mensaje de anoche")
                        Text(model.state.nightMessage)
                            .font(Theme.body(.title3, .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pipoCard()
                }

                if let alarm = model.alarm(record.alarmID), alarm.awakeCheck {
                    Text("Te preguntaré si sigues despierto a los 5 y a los 10 minutos.")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }

                Button("Empezar el día") {
                    model.newlyUnlocked = nil
                    onClose()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
            }
            .padding(20)
        }
        .screenBackground()
        .sensoryFeedback(.success, trigger: record.id)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(Theme.clock(28))
                .foregroundStyle(Theme.primaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .pipoCard()
        .accessibilityElement(children: .combine)
    }
}
