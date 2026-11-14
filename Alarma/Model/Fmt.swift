import Foundation

/// Formatos de fecha y hora en español.
enum Fmt {
    static let locale = Locale(identifier: "es_ES")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = format
        return f
    }

    static func time(_ date: Date) -> String { formatter("HH:mm").string(from: date) }

    static func hm(_ hour: Int, _ minute: Int) -> String { String(format: "%02d:%02d", hour, minute) }

    static func mmss(_ seconds: Int) -> String { String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60) }

    static func shortDateTime(_ date: Date) -> String { formatter("d MMM, HH:mm").string(from: date) }

    static func longDate(_ date: Date) -> String {
        let text = formatter("EEEE, d 'de' MMMM").string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "7 h 12 min", "25 min", "2 d 3 h".
    static func until(_ date: Date) -> String {
        let s = max(0, Int(date.timeIntervalSinceNow))
        let h = s / 3600
        let m = (s % 3600) / 60
        if h >= 24 { return "\(h / 24) d \(h % 24) h" }
        if h > 0 { return "\(h) h \(m) min" }
        return "\(max(1, m)) min"
    }

    /// "Hoy", "Mañana", "El lunes".
    static func dayWord(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hoy" }
        if cal.isDateInTomorrow(date) { return "Mañana" }
        return "El " + formatter("EEEE").string(from: date)
    }

    /// Orden lunes → domingo con su número de `Calendar` (1 = domingo).
    static let weekOrder: [(weekday: Int, letter: String, short: String, name: String)] = [
        (2, "L", "Lun", "lunes"), (3, "M", "Mar", "martes"), (4, "X", "Mié", "miércoles"),
        (5, "J", "Jue", "jueves"), (6, "V", "Vie", "viernes"), (7, "S", "Sáb", "sábado"), (1, "D", "Dom", "domingo")
    ]

    static func days(_ weekdays: [Int]) -> String {
        let set = Set(weekdays)
        if set.isEmpty { return "Una vez" }
        if set.count == 7 { return "Todos los días" }
        if set == [2, 3, 4, 5, 6] { return "Lun a Vie" }
        if set == [1, 7] { return "Sáb y Dom" }
        let names = weekOrder.filter { set.contains($0.weekday) }.map(\.short)
        if names.count == 2 { return names[0] + " y " + names[1] }
        return names.joined(separator: ", ")
    }

    static func challenges(_ alarm: AlarmItem) -> String {
        alarm.challenges.map { kind -> String in
            switch kind {
            case .steps: return "\(alarm.stepGoal) pasos"
            case .scan: return "escanear"
            case .math: return "\(alarm.mathCount) cuentas"
            case .photo: return "foto"
            }
        }.joined(separator: " + ")
    }
}
