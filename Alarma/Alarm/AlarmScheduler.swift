import Foundation
import SwiftUI
import AlarmKit
import ActivityKit
import AppIntents

/// Datos extra que viajan con cada alarma de AlarmKit.
struct PipoAlarmMetadata: AlarmMetadata {
    var kind: String = "main"
}

enum AlarmAuth {
    case unknown, notDetermined, authorized, denied
}

/// Envoltorio fino sobre AlarmKit. Cada alarma de Pipo (principal, respaldo o comprobación)
/// es una alarma de AlarmKit de fecha fija.
final class AlarmScheduler {
    private let manager = AlarmManager.shared

    var auth: AlarmAuth {
        switch manager.authorizationState {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .unknown
        }
    }

    var isAuthorized: Bool { auth == .authorized }

    func requestAuthorization() async -> Bool {
        do {
            let state = try await manager.requestAuthorization()
            return state == .authorized
        } catch {
            return false
        }
    }

    /// Programa una alarma de fecha fija y devuelve su identificador.
    func schedule(fire: Date, title: String, kind: EntryKind) async throws -> UUID {
        let id = UUID()
        let challengeButton = AlarmButton(
            text: "Hacer reto",
            textColor: .white,
            systemImageName: kind == .check ? "hand.raised.fill" : "figure.walk"
        )
        // En iOS 26.1+ el sistema dibuja su propio deslizador de "detener" e ignora este botón.
        let stopButton = AlarmButton(text: "Detener", textColor: .white, systemImageName: "stop.circle")
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: stopButton,
            secondaryButton: challengeButton,
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes<PipoAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: PipoAlarmMetadata(kind: kind.rawValue),
            tintColor: Theme.primary
        )
        let configuration = AlarmManager.AlarmConfiguration<PipoAlarmMetadata>.alarm(
            schedule: .fixed(fire),
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: id.uuidString),
            secondaryIntent: OpenChallengeIntent(alarmID: id.uuidString),
            sound: .default
        )
        _ = try await manager.schedule(id: id, configuration: configuration)
        return id
    }

    func cancel(_ id: UUID) {
        try? manager.cancel(id: id)
    }

    func stop(_ id: UUID) {
        try? manager.stop(id: id)
    }

    func scheduledIDs() -> [UUID] {
        ((try? manager.alarms) ?? []).map(\.id)
    }

    func alertingIDs() -> Set<UUID> {
        Set(((try? manager.alarms) ?? []).filter { $0.state == .alerting }.map(\.id))
    }
}
