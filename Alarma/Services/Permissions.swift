import Foundation
import AVFoundation
import CoreMotion
import Observation
import UIKit
import UserNotifications

enum PermissionStatus {
    case granted, denied, notAsked

    var text: String {
        switch self {
        case .granted: return "Permitido"
        case .denied: return "Denegado"
        case .notAsked: return "Sin pedir"
        }
    }
}

/// Estado de los permisos que necesita Pipo (las alarmas van aparte, en `AppModel`).
@Observable
final class Permissions {
    var motion: PermissionStatus = .notAsked
    var camera: PermissionStatus = .notAsked
    var notifications: PermissionStatus = .notAsked

    @ObservationIgnored private let pedometer = CMPedometer()

    func refresh() async {
        switch CMPedometer.authorizationStatus() {
        case .authorized: motion = .granted
        case .denied, .restricted: motion = .denied
        default: motion = .notAsked
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: camera = .granted
        case .denied, .restricted: camera = .denied
        default: camera = .notAsked
        }
        let settings = await UNUserNotificationCenterBridge.status()
        notifications = settings
    }

    func requestMotion() {
        // Consultar los pasos del último minuto hace que iOS muestre el permiso.
        pedometer.queryPedometerData(from: Date().addingTimeInterval(-60), to: Date()) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                Task { await self.refresh() }
            }
        }
    }

    func requestCamera() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        await refresh()
    }

    func requestNotifications() async {
        _ = await Notifier.requestAuthorization()
        await refresh()
    }

    @MainActor
    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

enum UNUserNotificationCenterBridge {
    static func status() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        default: return .notAsked
        }
    }
}
