import Foundation
import CoreMotion
import Observation

/// Cuenta los pasos dados desde que empieza el reto.
/// Si te paras 30 segundos, el contador baja 10 pasos (y otros 10 cada 30 s más).
@Observable
final class StepCounter {
    var rawSteps = 0
    var penalty = 0
    var idleSeconds = 0
    var errorText: String?

    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private var lastStepAt = Date()
    @ObservationIgnored private var timer: Timer?

    static let idleLimit = 30
    static let penaltySteps = 10

    var progress: Int { max(0, rawSteps - penalty) }

    var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    func start() {
        stop()
        rawSteps = 0
        penalty = 0
        idleSeconds = 0
        errorText = nil
        lastStepAt = Date()

        guard CMPedometer.isStepCountingAvailable() else {
            errorText = "Este iPhone no puede contar pasos."
            return
        }

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            let steps = data?.numberOfSteps.intValue
            let message = error?.localizedDescription
            DispatchQueue.main.async {
                guard let self else { return }
                if let message {
                    self.errorText = "No puedo leer los pasos: \(message). Revisa el permiso de Movimiento en Ajustes."
                    return
                }
                if let steps, steps > self.rawSteps {
                    self.rawSteps = steps
                    self.lastStepAt = Date()
                    self.idleSeconds = 0
                }
            }
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        idleSeconds = Int(Date().timeIntervalSince(lastStepAt))
        if idleSeconds >= Self.idleLimit {
            if progress > 0 {
                penalty += min(Self.penaltySteps, progress)
            }
            lastStepAt = Date()
            idleSeconds = 0
        }
    }

    func stop() {
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil
    }

    deinit {
        pedometer.stopUpdates()
        timer?.invalidate()
    }
}
