import Foundation
import AlarmKit
import AppIntents
import ActivityKit

/// Botón "Hacer reto" de la alarma: calla la alarma que está sonando y abre Pipo.
/// Los respaldos siguen programados hasta que completes el reto.
struct OpenChallengeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Hacer reto"
    static var description = IntentDescription("Abre Pipo para hacer el reto y apagar la alarma.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Identificador de la alarma")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            // Primero se marca, para que callarla no la haga volver a sonar.
            AppModel.shared.markChallengeOpened(akID: id)
            try? AlarmManager.shared.stop(id: id)
        }
        UserDefaults.standard.set(alarmID, forKey: "pendingAlarmID")
        return .result()
    }
}

/// Deslizador de "detener": calla la alarma y, si el reto sigue sin hacer,
/// programa otra para dentro de 30 segundos.
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Detener"
    static var description = IntentDescription("Detiene la alarma. Si no has hecho el reto, vuelve a sonar en 30 segundos.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Identificador de la alarma")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        try? AlarmManager.shared.stop(id: id)
        await AppModel.shared.alarmWasStopped(akID: id)
        return .result()
    }
}
