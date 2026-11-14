import Foundation
import Observation
import UIKit

/// Pantalla de despertar que se abre a pantalla completa.
enum WakeRoute: Identifiable, Equatable {
    case session(alarmID: UUID, occurrence: Date)
    case check(UUID)

    var id: String {
        switch self {
        case .session(let alarmID, let occurrence):
            return "s-\(alarmID.uuidString)-\(Int(occurrence.timeIntervalSince1970))"
        case .check(let id):
            return "c-\(id.uuidString)"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var state: PersistedState
    var route: WakeRoute?
    var alarmAuth: AlarmAuth = .unknown
    var signingExpiry: Date?
    var batteryLow = false
    /// Accesorio recién desbloqueado en el último reto (para la pantalla de "completado").
    var newlyUnlocked: Accessory?

    @ObservationIgnored private let scheduler = AlarmScheduler()
    @ObservationIgnored private var reconciling = false
    @ObservationIgnored private var reconcileAgain = false

    /// Las alarmas principales se programan con 7 días de antelación;
    /// los respaldos solo para lo que suene en las próximas 26 horas.
    private let mainHorizonDays = 7
    private let backupHorizon: TimeInterval = 26 * 3600

    init() {
        state = Persistence.load()
        signingExpiry = SigningInfo.expirationDate()
    }

    // MARK: - Guardado y registro

    func save() {
        Persistence.save(state)
    }

    func log(_ text: String) {
        let line = "\(Fmt.shortDateTime(Date())) · \(text)"
        state.events.insert(line, at: 0)
        if state.events.count > 80 {
            state.events.removeLast(state.events.count - 80)
        }
    }

    // MARK: - Ciclo de vida

    /// Se llama al abrir la app y cada vez que vuelve al primer plano.
    func refresh() async {
        alarmAuth = scheduler.auth
        updateBattery()
        signingExpiry = SigningInfo.expirationDate()
        if let expiry = signingExpiry {
            Notifier.scheduleSigningReminder(expiry: expiry)
        }
        cleanupTests()
        await reconcile()
        UserDefaults.standard.removeObject(forKey: "pendingAlarmID")
        detectRoute()
        save()
    }

    func requestAlarmAuthorization() async {
        let ok = await scheduler.requestAuthorization()
        alarmAuth = scheduler.auth
        log(ok ? "Permiso de alarmas concedido" : "Permiso de alarmas denegado")
        if ok { await reconcile() }
        save()
    }

    func updateBattery() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        batteryLow = level >= 0 && level < 0.3 && device.batteryState == .unplugged
    }

    // MARK: - Alarmas

    func alarm(_ id: UUID) -> AlarmItem? {
        state.alarms.first { $0.id == id }
    }

    var visibleAlarms: [AlarmItem] {
        state.alarms.filter { !$0.isTest }
    }

    func upsert(_ item: AlarmItem) {
        var item = item
        item.editedAt = Date()
        if item.weekdays.isEmpty {
            item.oneShot = nextFire(hour: item.hour, minute: item.minute)
        } else {
            item.oneShot = nil
        }
        if let index = state.alarms.firstIndex(where: { $0.id == item.id }) {
            state.alarms[index] = item
            log("Alarma de las \(Fmt.hm(item.hour, item.minute)) actualizada")
        } else {
            state.alarms.append(item)
            log("Alarma de las \(Fmt.hm(item.hour, item.minute)) creada")
        }
        sortAlarms()
        save()
        Task { await reconcile() }
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        guard let index = state.alarms.firstIndex(where: { $0.id == id }) else { return }
        state.alarms[index].enabled = enabled
        if enabled {
            state.alarms[index].editedAt = Date()
            if state.alarms[index].weekdays.isEmpty && !state.alarms[index].isTest {
                state.alarms[index].oneShot = nextFire(hour: state.alarms[index].hour, minute: state.alarms[index].minute)
            }
        }
        log("Alarma de las \(Fmt.hm(state.alarms[index].hour, state.alarms[index].minute)) \(enabled ? "activada" : "desactivada")")
        save()
        Task { await reconcile() }
    }

    func delete(_ id: UUID) {
        guard let alarm = self.alarm(id) else { return }
        state.alarms.removeAll { $0.id == id }
        state.pendingChecks.removeAll { $0.alarmID == id }
        log("Alarma de las \(Fmt.hm(alarm.hour, alarm.minute)) borrada")
        save()
        Task { await reconcile() }
    }

    private func sortAlarms() {
        state.alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    /// Modo estricto: en las 10 horas antes de que suene no se puede tocar sin hacer cuentas.
    func isLocked(_ alarm: AlarmItem) -> Bool {
        guard alarm.strict, alarm.enabled, let next = nextOccurrence(alarm) else { return false }
        return next.timeIntervalSinceNow < 10 * 3600
    }

    func scheduleTest() {
        var test = AlarmItem()
        test.label = "Prueba"
        test.isTest = true
        test.weekdays = []
        test.oneShot = Date().addingTimeInterval(60)
        test.challenges = [.steps]
        test.stepGoal = 20
        test.backupInterval = 1
        test.backupCount = 3
        test.awakeCheck = false
        test.editedAt = Date()
        state.alarms.append(test)
        log("Alarma de prueba para las \(Fmt.time(test.oneShot ?? Date()))")
        save()
        Task { await reconcile() }
    }

    private func cleanupTests() {
        let limit = Date().addingTimeInterval(-3600)
        state.alarms.removeAll { $0.isTest && ($0.oneShot ?? .distantPast) < limit }
    }

    // MARK: - Fechas

    private func nextFire(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        let today = cal.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        return today > now ? today : (cal.date(byAdding: .day, value: 1, to: today) ?? today)
    }

    func occurrences(of alarm: AlarmItem, from start: Date, days: Int) -> [Date] {
        if let one = alarm.oneShot {
            return (one >= start && one > alarm.editedAt) ? [one] : []
        }
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        var result: [Date] = []
        for offset in 0...days {
            guard let day = cal.date(byAdding: .day, value: offset, to: startDay),
                  let fire = cal.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: day) else { continue }
            guard fire >= start, fire > alarm.editedAt else { continue }
            if alarm.weekdays.isEmpty {
                result.append(fire)
                break
            }
            if alarm.weekdays.contains(cal.component(.weekday, from: fire)) {
                result.append(fire)
            }
        }
        return result
    }

    func nextOccurrence(_ alarm: AlarmItem) -> Date? {
        occurrences(of: alarm, from: Date(), days: 8).first
    }

    /// La próxima alarma activa que va a sonar.
    var nextAlarm: (alarm: AlarmItem, date: Date)? {
        visibleAlarms
            .filter(\.enabled)
            .compactMap { alarm in nextOccurrence(alarm).map { (alarm: alarm, date: $0) } }
            .min { $0.date < $1.date }
    }

    private func key(_ alarmID: UUID, _ occurrence: Date) -> String {
        "\(alarmID.uuidString)|\(Int(occurrence.timeIntervalSince1970))"
    }

    func isCompleted(_ alarmID: UUID, _ occurrence: Date) -> Bool {
        state.completedKeys.contains(key(alarmID, occurrence))
    }

    var futureScheduledCount: Int {
        let now = Date()
        return state.scheduled.filter { $0.fire > now }.count
    }

    func nextBackup(alarmID: UUID, occurrence: Date) -> Date? {
        let now = Date()
        return state.scheduled
            .filter { $0.alarmID == alarmID && $0.occurrence == occurrence && $0.kind == .backup && $0.fire > now }
            .map(\.fire)
            .min()
    }

    func backupsRung(alarmID: UUID, occurrence: Date) -> Int {
        let now = Date()
        return state.scheduled.filter {
            $0.alarmID == alarmID && $0.occurrence == occurrence && $0.kind == .backup && $0.fire <= now
        }.count
    }

    // MARK: - Programación en AlarmKit

    /// Compara lo que debería estar programado con lo que hay, y cancela o programa lo que sobre o falte.
    func reconcile() async {
        if reconciling {
            reconcileAgain = true
            return
        }
        reconciling = true
        repeat {
            reconcileAgain = false
            await reconcileOnce()
        } while reconcileAgain
        reconciling = false
        save()
    }

    private func reconcileOnce() async {
        alarmAuth = scheduler.auth
        guard scheduler.isAuthorized else { return }
        let now = Date()
        let soon = now.addingTimeInterval(3)

        var desired: [ScheduledEntry] = []
        for alarm in state.alarms where alarm.enabled {
            let start = now.addingTimeInterval(-alarm.backupWindow - 60)
            for occurrence in occurrences(of: alarm, from: start, days: mainHorizonDays) {
                if isCompleted(alarm.id, occurrence) { continue }
                if occurrence > soon {
                    desired.append(ScheduledEntry(akID: UUID(), alarmID: alarm.id, kind: .main,
                                                  occurrence: occurrence, fire: occurrence, group: nil))
                }
                if occurrence < now.addingTimeInterval(backupHorizon), alarm.backupCount > 0 {
                    for index in 1...alarm.backupCount {
                        let fire = occurrence.addingTimeInterval(TimeInterval(index * alarm.backupInterval * 60))
                        if fire > soon {
                            desired.append(ScheduledEntry(akID: UUID(), alarmID: alarm.id, kind: .backup,
                                                          occurrence: occurrence, fire: fire, group: nil))
                        }
                    }
                }
            }
        }
        for check in state.pendingChecks where !check.confirmed {
            let first = check.fires.first ?? now
            for fire in check.fires where fire > soon {
                desired.append(ScheduledEntry(akID: UUID(), alarmID: check.alarmID, kind: .check,
                                              occurrence: first, fire: fire, group: check.id))
            }
        }

        let desiredKeys = Set(desired.map(\.key))
        var kept: [ScheduledEntry] = []
        for entry in state.scheduled {
            if entry.fire > now {
                if desiredKeys.contains(entry.key) {
                    kept.append(entry)
                } else {
                    scheduler.cancel(entry.akID)
                }
            } else if now.timeIntervalSince(entry.fire) < 3 * 3600 {
                // Ya sonó: se guarda un rato para saber a qué mañana pertenece.
                kept.append(entry)
            } else if entry.kind == .main {
                recordMissedIfNeeded(entry)
            }
        }

        let keptKeys = Set(kept.map(\.key))
        var added = 0
        for var entry in desired where !keptKeys.contains(entry.key) {
            do {
                entry.akID = try await scheduler.schedule(fire: entry.fire, title: title(for: entry), kind: entry.kind)
                kept.append(entry)
                added += 1
            } catch {
                log("No se pudo programar la alarma de las \(Fmt.time(entry.fire)): \(error.localizedDescription)")
                break
            }
        }

        // Alarmas de AlarmKit que ya no reconocemos.
        let known = Set(kept.map(\.akID))
        for id in scheduler.scheduledIDs() where !known.contains(id) {
            scheduler.cancel(id)
        }

        state.scheduled = kept.sorted { $0.fire < $1.fire }
        state.pendingChecks.removeAll { $0.confirmed || ($0.fires.last ?? .distantPast) < now.addingTimeInterval(-3600) }
        if state.completedKeys.count > 400 {
            state.completedKeys.removeFirst(state.completedKeys.count - 400)
        }
        if added > 0 {
            log("Programadas \(added) alarmas nuevas (\(futureScheduledCount) en total)")
        }
    }

    private func title(for entry: ScheduledEntry) -> String {
        let label = alarm(entry.alarmID)?.label ?? "Alarma"
        switch entry.kind {
        case .main: return "¡Arriba! \(label)"
        case .backup: return "Pipo sigue aquí · haz el reto"
        case .check: return "¿Sigues despierto?"
        }
    }

    private func recordMissedIfNeeded(_ entry: ScheduledEntry) {
        guard !isCompleted(entry.alarmID, entry.occurrence),
              !state.records.contains(where: { $0.alarmID == entry.alarmID && $0.occurrence == entry.occurrence }),
              let alarm = self.alarm(entry.alarmID), !alarm.isTest else { return }
        state.records.append(WakeRecord(alarmID: alarm.id, label: alarm.label, occurrence: entry.occurrence,
                                        completedAt: nil, backupsRung: alarm.backupCount, challengeSeconds: 0))
        log("La alarma de las \(Fmt.time(entry.occurrence)) terminó sin completar el reto")
    }

    // MARK: - Despertar

    /// Decide si hay que abrir la pantalla de despertar o la de "¿sigues despierto?".
    func detectRoute() {
        guard route == nil else { return }
        let now = Date()
        let mains = state.scheduled
            .filter { $0.kind == .main && $0.fire <= now }
            .sorted { $0.fire > $1.fire }
        for entry in mains {
            guard let alarm = self.alarm(entry.alarmID) else { continue }
            let window = alarm.backupWindow + 5 * 60
            if now.timeIntervalSince(entry.fire) <= window && !isCompleted(alarm.id, entry.occurrence) {
                route = .session(alarmID: alarm.id, occurrence: entry.occurrence)
                return
            }
        }
        if let check = state.pendingChecks.first(where: { !$0.confirmed && ($0.fires.first ?? .distantFuture) <= now }) {
            route = .check(check.id)
        }
    }

    /// Calla lo que esté sonando de esta mañana (los respaldos futuros siguen).
    func beginSession(alarmID: UUID, occurrence: Date) {
        let now = Date().addingTimeInterval(1)
        for entry in state.scheduled where entry.alarmID == alarmID && entry.occurrence == occurrence && entry.fire <= now {
            scheduler.stop(entry.akID)
        }
        log("Empieza el reto de las \(Fmt.time(occurrence))")
    }

    func tasks(for alarm: AlarmItem?) -> [ChallengeTask] {
        guard let alarm else { return [.steps(100)] }
        var tasks: [ChallengeTask] = []
        for kind in alarm.challenges {
            switch kind {
            case .steps:
                tasks.append(.steps(alarm.stepGoal))
            case .scan:
                tasks.append(state.savedCode != nil ? .scan : .steps(alarm.stepGoal * 2))
            case .math:
                tasks.append(.math(alarm.mathCount))
            case .photo:
                tasks.append(Persistence.hasReferencePhoto ? .photo : .math(max(alarm.mathCount, 8)))
            }
        }
        return tasks.isEmpty ? [.steps(100)] : tasks
    }

    @discardableResult
    func completeSession(alarmID: UUID, occurrence: Date, startedAt: Date) -> WakeRecord {
        let now = Date()
        let alarm = self.alarm(alarmID)
        let bestBefore = bestStreak()
        state.completedKeys.append(key(alarmID, occurrence))
        let rung = backupsRung(alarmID: alarmID, occurrence: occurrence)

        for entry in state.scheduled where entry.alarmID == alarmID && entry.occurrence == occurrence {
            if entry.fire <= now {
                scheduler.stop(entry.akID)
            } else {
                scheduler.cancel(entry.akID)
            }
        }
        state.scheduled.removeAll { $0.alarmID == alarmID && $0.occurrence == occurrence && $0.fire > now }

        let record = WakeRecord(alarmID: alarmID, label: alarm?.label ?? "Alarma", occurrence: occurrence,
                                completedAt: now, backupsRung: rung,
                                challengeSeconds: max(1, Int(now.timeIntervalSince(startedAt))))
        if alarm?.isTest != true {
            state.records.append(record)
        }

        if let alarm, alarm.awakeCheck {
            for minutes in [[5, 6, 7], [10, 11, 12]] {
                state.pendingChecks.append(PendingCheck(alarmID: alarmID,
                                                        fires: minutes.map { now.addingTimeInterval(TimeInterval($0 * 60)) }))
            }
        }

        if let alarm {
            if alarm.isTest {
                state.alarms.removeAll { $0.id == alarm.id }
            } else if alarm.oneShot != nil, let index = state.alarms.firstIndex(where: { $0.id == alarm.id }) {
                state.alarms[index].enabled = false
            }
        }

        let bestAfter = bestStreak()
        newlyUnlocked = Accessory.allCases.last { bestBefore < $0.streakNeeded && bestAfter >= $0.streakNeeded }
        if let unlocked = newlyUnlocked, state.equipped == nil || state.equipped == .hat {
            state.equipped = unlocked
        }

        log("Reto completado en \(Fmt.mmss(record.challengeSeconds)) (\(rung) respaldos sonaron)")
        save()
        Task { await reconcile() }
        return record
    }

    func startCheck(_ id: UUID) {
        let now = Date().addingTimeInterval(1)
        for entry in state.scheduled where entry.group == id && entry.fire <= now {
            scheduler.stop(entry.akID)
        }
    }

    func confirmCheck(_ id: UUID) {
        guard let index = state.pendingChecks.firstIndex(where: { $0.id == id }) else { return }
        state.pendingChecks[index].confirmed = true
        let now = Date()
        for entry in state.scheduled where entry.group == id {
            if entry.fire <= now {
                scheduler.stop(entry.akID)
            } else {
                scheduler.cancel(entry.akID)
            }
        }
        state.scheduled.removeAll { $0.group == id && $0.fire > now }
        log("Comprobación superada: sigues despierto")
        save()
        Task { await reconcile() }
    }

    func nextCheckFire(_ id: UUID) -> Date? {
        let now = Date()
        return state.pendingChecks.first { $0.id == id }?.fires.first { $0 > now }
    }

    // MARK: - Estadísticas

    /// Día → ¿todo bien ese día? (sin ninguna alarma fallada)
    private func dayStatus() -> [Date: Bool] {
        let cal = Calendar.current
        var status: [Date: Bool] = [:]
        for record in state.records {
            let day = cal.startOfDay(for: record.occurrence)
            status[day] = (status[day] ?? true) && record.completed
        }
        return status
    }

    /// Días seguidos (con alarma) levantándote a la primera.
    func currentStreak() -> Int {
        let status = dayStatus()
        var count = 0
        for day in status.keys.sorted(by: >) {
            if status[day] == true { count += 1 } else { break }
        }
        return count
    }

    func bestStreak() -> Int {
        let status = dayStatus()
        var best = 0
        var run = 0
        for day in status.keys.sorted() {
            if status[day] == true {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    struct DayBar: Identifiable {
        let id: Date
        let letter: String
        let minutes: Int?
        let isToday: Bool
    }

    /// Minutos que tardaste en completar el reto los últimos 7 días.
    func lastWeekBars() -> [DayBar] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { back -> DayBar? in
            guard let day = cal.date(byAdding: .day, value: -back, to: today) else { return nil }
            let weekday = cal.component(.weekday, from: day)
            let letter = Fmt.weekOrder.first { $0.weekday == weekday }?.letter ?? "?"
            let seconds = state.records
                .filter { $0.completed && cal.isDate($0.occurrence, inSameDayAs: day) }
                .map(\.challengeSeconds)
                .min()
            let minutes = seconds.map { max(1, Int((Double($0) / 60).rounded(.up))) }
            return DayBar(id: day, letter: letter, minutes: minutes, isToday: back == 0)
        }
    }

    /// Los 7 últimos días con alarma: true = superado, false = fallado.
    func recentDays() -> [(letter: String, ok: Bool)] {
        let status = dayStatus()
        let cal = Calendar.current
        return status.keys.sorted().suffix(7).map { day in
            let weekday = cal.component(.weekday, from: day)
            let letter = Fmt.weekOrder.first { $0.weekday == weekday }?.letter ?? "?"
            return (letter: letter, ok: status[day] == true)
        }
    }

    var averageWakeTime: String? {
        let cal = Calendar.current
        let recent = state.records.compactMap(\.completedAt).suffix(14)
        guard !recent.isEmpty else { return nil }
        let minutes = recent.map { cal.component(.hour, from: $0) * 60 + cal.component(.minute, from: $0) }
        let average = minutes.reduce(0, +) / minutes.count
        return Fmt.hm(average / 60, average % 60)
    }

    var backupsThisWeek: Int {
        let limit = Date().addingTimeInterval(-7 * 86400)
        return state.records.filter { $0.occurrence > limit }.map(\.backupsRung).reduce(0, +)
    }

    var missedThisWeek: Int {
        let limit = Date().addingTimeInterval(-7 * 86400)
        return state.records.filter { $0.occurrence > limit && !$0.completed }.count
    }

    func isUnlocked(_ accessory: Accessory) -> Bool {
        bestStreak() >= accessory.streakNeeded
    }

    func equip(_ accessory: Accessory?) {
        state.equipped = accessory
        save()
    }
}
