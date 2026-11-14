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

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        UserDefaults.standard.set(alarmID, forKey: "pendingAlarmID")
        return .result()
    }
}
