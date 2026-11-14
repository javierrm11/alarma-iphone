import Foundation
import UserNotifications

/// Avisos normales (no alarmas): recordatorio de renovar la firma de la app.
enum Notifier {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    static func scheduleSigningReminder(expiry: Date) {
        let center = UNUserNotificationCenter.current()
        let ids = ["firma-2d", "firma-1d"]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let cal = Calendar.current
        for (index, daysBefore) in [2, 1].enumerated() {
            guard let day = cal.date(byAdding: .day, value: -daysBefore, to: expiry),
                  let date = cal.date(bySettingHour: 21, minute: 0, second: 0, of: day),
                  date > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Pipo caduca pronto"
            content.body = daysBefore == 1
                ? "Mañana caduca la firma. Renueva la app en SideStore o la alarma no sonará."
                : "Quedan 2 días de firma. Renueva la app en SideStore."
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let request = UNNotificationRequest(
                identifier: ids[index],
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            center.add(request)
        }
    }
}
