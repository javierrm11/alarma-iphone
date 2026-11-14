import Foundation

// MARK: - Retos

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case steps, scan, math, photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: return "Pasos"
        case .scan: return "Escanear"
        case .math: return "Cuentas"
        case .photo: return "Foto"
        }
    }

    var symbol: String {
        switch self {
        case .steps: return "figure.walk"
        case .scan: return "barcode.viewfinder"
        case .math: return "plus.forwardslash.minus"
        case .photo: return "camera"
        }
    }
}

/// Un paso concreto del reto de una mañana (ya con sus parámetros).
enum ChallengeTask: Hashable {
    case steps(Int)
    case scan
    case math(Int)
    case photo

    var title: String {
        switch self {
        case .steps(let n): return "Anda \(n) pasos"
        case .scan: return "Busca el código"
        case .math(let n): return "Resuelve \(n) cuentas"
        case .photo: return "Haz la foto"
        }
    }

    var shortText: String {
        switch self {
        case .steps(let n): return "\(n) pasos"
        case .scan: return "escanear"
        case .math(let n): return "\(n) cuentas"
        case .photo: return "foto"
        }
    }
}

// MARK: - Accesorios de Pipo

enum Accessory: String, Codable, CaseIterable, Identifiable {
    case hat, scarf, glasses, crown

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hat: return "Gorro de dormir"
        case .scarf: return "Bufanda"
        case .glasses: return "Gafas de sol"
        case .crown: return "Corona"
        }
    }

    /// Racha (días seguidos) necesaria para desbloquearlo.
    var streakNeeded: Int {
        switch self {
        case .hat: return 1
        case .scarf: return 3
        case .glasses: return 7
        case .crown: return 30
        }
    }
}

// MARK: - Alarma

struct AlarmItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var hour = 7
    var minute = 0
    /// Días de la semana según `Calendar`: 1 = domingo … 7 = sábado. Vacío = una sola vez.
    var weekdays: [Int] = [2, 3, 4, 5, 6]
    var label = "Alarma"
    var enabled = true
    var challenges: [ChallengeKind] = [.steps]
    var stepGoal = 100
    var mathCount = 5
    var backupInterval = 2
    var backupCount = 15
    var awakeCheck = true
    var strict = false
    /// Fecha concreta para alarmas de una sola vez (y la alarma de prueba).
    var oneShot: Date?
    var isTest = false
    /// Solo cuentan las veces que suena después de crearla o editarla.
    var editedAt = Date()

    init() {}

    enum CodingKeys: String, CodingKey {
        case id, hour, minute, weekdays, label, enabled, challenges, stepGoal, mathCount
        case backupInterval, backupCount, awakeCheck, strict, oneShot, isTest, editedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AlarmItem()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? d.id
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? d.hour
        minute = try c.decodeIfPresent(Int.self, forKey: .minute) ?? d.minute
        weekdays = try c.decodeIfPresent([Int].self, forKey: .weekdays) ?? d.weekdays
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? d.label
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        challenges = try c.decodeIfPresent([ChallengeKind].self, forKey: .challenges) ?? d.challenges
        stepGoal = try c.decodeIfPresent(Int.self, forKey: .stepGoal) ?? d.stepGoal
        mathCount = try c.decodeIfPresent(Int.self, forKey: .mathCount) ?? d.mathCount
        backupInterval = try c.decodeIfPresent(Int.self, forKey: .backupInterval) ?? d.backupInterval
        backupCount = try c.decodeIfPresent(Int.self, forKey: .backupCount) ?? d.backupCount
        awakeCheck = try c.decodeIfPresent(Bool.self, forKey: .awakeCheck) ?? d.awakeCheck
        strict = try c.decodeIfPresent(Bool.self, forKey: .strict) ?? d.strict
        oneShot = try c.decodeIfPresent(Date.self, forKey: .oneShot)
        isTest = try c.decodeIfPresent(Bool.self, forKey: .isTest) ?? d.isTest
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt) ?? .distantPast
    }

    /// Ventana en la que siguen sonando respaldos tras la alarma principal.
    var backupWindow: TimeInterval { TimeInterval(backupInterval * backupCount * 60) }
}

// MARK: - Lo que hay programado en el sistema

enum EntryKind: String, Codable {
    case main, backup, check
}

struct ScheduledEntry: Codable, Hashable {
    /// Identificador de la alarma en AlarmKit.
    var akID: UUID
    var alarmID: UUID
    var kind: EntryKind
    var occurrence: Date
    var fire: Date
    var group: UUID?

    var key: String {
        "\(alarmID.uuidString)|\(kind.rawValue)|\(Int(fire.timeIntervalSince1970))|\(group?.uuidString ?? "-")"
    }
}

struct PendingCheck: Codable, Identifiable, Hashable {
    var id = UUID()
    var alarmID: UUID
    var fires: [Date]
    var confirmed = false
}

struct WakeRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var alarmID: UUID
    var label: String
    var occurrence: Date
    var completedAt: Date?
    var backupsRung: Int
    var challengeSeconds: Int

    var completed: Bool { completedAt != nil }
}

struct SavedCode: Codable, Hashable {
    var name: String
    var payload: String
}

// MARK: - Estado guardado

struct PersistedState: Codable {
    var alarms: [AlarmItem] = []
    var scheduled: [ScheduledEntry] = []
    var completedKeys: [String] = []
    var pendingChecks: [PendingCheck] = []
    var records: [WakeRecord] = []
    var savedCode: SavedCode?
    var photoThreshold: Double = 0.75
    var nightMessage = ""
    var equipped: Accessory?
    var onboardingDone = false
    var events: [String] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case alarms, scheduled, completedKeys, pendingChecks, records, savedCode
        case photoThreshold, nightMessage, equipped, onboardingDone, events
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alarms = (try? c.decodeIfPresent([AlarmItem].self, forKey: .alarms)) ?? []
        scheduled = (try? c.decodeIfPresent([ScheduledEntry].self, forKey: .scheduled)) ?? []
        completedKeys = (try? c.decodeIfPresent([String].self, forKey: .completedKeys)) ?? []
        pendingChecks = (try? c.decodeIfPresent([PendingCheck].self, forKey: .pendingChecks)) ?? []
        records = (try? c.decodeIfPresent([WakeRecord].self, forKey: .records)) ?? []
        savedCode = try? c.decodeIfPresent(SavedCode.self, forKey: .savedCode)
        photoThreshold = (try? c.decodeIfPresent(Double.self, forKey: .photoThreshold)) ?? 0.75
        nightMessage = (try? c.decodeIfPresent(String.self, forKey: .nightMessage)) ?? ""
        equipped = try? c.decodeIfPresent(Accessory.self, forKey: .equipped)
        onboardingDone = (try? c.decodeIfPresent(Bool.self, forKey: .onboardingDone)) ?? false
        events = (try? c.decodeIfPresent([String].self, forKey: .events)) ?? []
    }
}

enum Persistence {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pipo", isDirectory: true)
    }

    static var stateURL: URL { folder.appendingPathComponent("estado.json") }
    static var referencePhotoURL: URL { folder.appendingPathComponent("foto-referencia.jpg") }

    static func load() -> PersistedState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return PersistedState()
        }
        return state
    }

    static func save(_ state: PersistedState) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }

    static var hasReferencePhoto: Bool {
        FileManager.default.fileExists(atPath: referencePhotoURL.path)
    }
}
