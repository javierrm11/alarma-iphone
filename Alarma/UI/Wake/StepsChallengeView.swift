import SwiftUI

struct StepsChallengeView: View {
    let goal: Int
    let header: ChallengeHeader
    let onDone: () -> Void
    var onFallback: () -> Void = {}

    @Environment(AppModel.self) private var model
    @State private var counter = StepCounter()
    @State private var finished = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                RingView(progress: Double(counter.progress) / Double(max(goal, 1)), lineWidth: 20) {
                    VStack(spacing: 4) {
                        Text("\(min(counter.progress, goal))")
                            .font(Theme.clock(56))
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                        Text("de \(goal) pasos")
                            .font(Theme.body(.subheadline))
                            .foregroundStyle(Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
                .frame(width: 250, height: 250)

                HStack(alignment: .center, spacing: 10) {
                    PipoView(mood: counter.idleSeconds >= 15 ? .suspicious : .happy, accessory: model.state.equipped, size: 72)
                    SpeechBubble(text: cheer)
                }

                if let error = counter.errorText {
                    WarningCard(icon: "figure.walk.motion.trianglebadge.exclamationmark", title: "No puedo contar pasos",
                                text: error, button: "Hacer 10 cuentas en su lugar") {
                        counter.stop()
                        onFallback()
                    }
                }

                Text("Pipo camina contigo. Si os paráis \(StepCounter.idleLimit) s, el contador baja \(StepCounter.penaltySteps) pasos.")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .onAppear { counter.start() }
        .onDisappear { counter.stop() }
        .onChange(of: counter.progress) { _, value in
            if value >= goal { finish() }
        }
        .sensoryFeedback(.success, trigger: finished)
    }

    private var cheer: String {
        let left = goal - counter.progress
        if counter.idleSeconds >= 15 {
            return "¡No pares! En \(StepCounter.idleLimit - counter.idleSeconds) s el contador baja."
        }
        if counter.progress == 0 { return "¡Venga, levántate y a andar!" }
        if left <= goal / 4 { return "¡Así me gusta! Ya casi estamos." }
        return "Bien, sigue así. Te quedan \(left) pasos."
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        counter.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onDone() }
    }
}
