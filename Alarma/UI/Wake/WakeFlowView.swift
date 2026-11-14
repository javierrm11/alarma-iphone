import SwiftUI

/// Flujo completo de una mañana: pantalla de alarma → retos → completado.
struct WakeFlowView: View {
    let alarmID: UUID
    let occurrence: Date

    @Environment(AppModel.self) private var model
    @State private var phase: Phase = .intro
    @State private var tasks: [ChallengeTask] = []
    @State private var index = 0
    @State private var startedAt = Date()
    @State private var record: WakeRecord?

    enum Phase { case intro, challenge, done }

    private var alarm: AlarmItem? { model.alarm(alarmID) }

    var body: some View {
        ZStack {
            (phase == .intro ? Theme.surface2 : Theme.bg).ignoresSafeArea()
            switch phase {
            case .intro:
                WakeIntroView(alarm: alarm, occurrence: occurrence, tasks: tasks, nextBackup: model.nextBackup(alarmID: alarmID, occurrence: occurrence)) {
                    model.beginSession(alarmID: alarmID, occurrence: occurrence)
                    startedAt = Date()
                    withAnimation { phase = .challenge }
                }
            case .challenge:
                challengeView
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .done:
                if let record {
                    DoneView(record: record) { model.route = nil }
                }
            }
        }
        .onAppear {
            if tasks.isEmpty { tasks = model.tasks(for: alarm) }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var challengeView: some View {
        if index < tasks.count {
            let header = ChallengeHeader(index: index, total: tasks.count, title: tasks[index].title,
                                         nextBackup: model.nextBackup(alarmID: alarmID, occurrence: occurrence),
                                         after: index + 1 < tasks.count ? tasks[index + 1].shortText : nil)
            switch tasks[index] {
            case .steps(let goal):
                StepsChallengeView(goal: goal, header: header, onDone: next) {
                    replaceCurrent(with: .math(10))
                }
            case .scan:
                ScanChallengeView(header: header, onDone: next) {
                    replaceCurrent(with: .steps(300))
                }
            case .math(let count):
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        PipoView(mood: .awake, accessory: model.state.equipped, size: 90)
                        MathChallengeView(count: count, hard: false, onDone: next)
                    }
                    .padding(20)
                }
            case .photo:
                PhotoChallengeView(header: header, onDone: next) {
                    replaceCurrent(with: .math(10))
                }
            }
        }
    }

    private func replaceCurrent(with task: ChallengeTask) {
        guard index < tasks.count else { return }
        tasks[index] = task
        model.log("Reto cambiado a \(task.shortText)")
    }

    private func next() {
        if index + 1 < tasks.count {
            withAnimation { index += 1 }
        } else {
            record = model.completeSession(alarmID: alarmID, occurrence: occurrence, startedAt: startedAt)
            withAnimation { phase = .done }
        }
    }
}

/// Cabecera común de los retos: "Reto 1 de 2" + título + lo que viene después.
struct ChallengeHeader: View {
    let index: Int
    let total: Int
    let title: String
    let nextBackup: Date?
    let after: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(total > 1 ? "Reto \(index + 1) de \(total)" : "Reto")
            Text(title)
                .font(Theme.display(.title, .semibold))
                .foregroundStyle(Theme.text)
            HStack(spacing: 6) {
                if let nextBackup {
                    Chip(text: "Próximo respaldo: \(Fmt.time(nextBackup))", color: Theme.primaryText)
                }
                if let after {
                    Chip(text: "Después: \(after)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pantalla 3: lo que ves al abrir Pipo desde la alarma.
struct WakeIntroView: View {
    let alarm: AlarmItem?
    let occurrence: Date
    let tasks: [ChallengeTask]
    let nextBackup: Date?
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                SectionLabel(Fmt.longDate(occurrence))
                Text("¡Arriba, dormilón!")
                    .font(Theme.display(.title2, .bold))
                    .foregroundStyle(Theme.primaryText)
            }
            .padding(.top, 24)

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                SpeechBubble(text: "¡Arriba! Hoy toca \(tasks.map(\.shortText).joined(separator: " + ")) conmigo.", centered: true)
                PipoView(mood: .shout, size: 170)
            }

            Text(Fmt.time(occurrence))
                .font(Theme.clock(84))
                .foregroundStyle(Theme.text)
            Text(alarm?.label ?? "Alarma")
                .font(Theme.body(.body))
                .foregroundStyle(Theme.muted)

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                Button(action: onStart) {
                    Label("¡Vamos allá!", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                Text(nextBackup.map { "Si no haces el reto, vuelvo a sonar a las \(Fmt.time($0))." }
                     ?? "Si no haces el reto, vuelvo a sonar en unos minutos.")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }
}
