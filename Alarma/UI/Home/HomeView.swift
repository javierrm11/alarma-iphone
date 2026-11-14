import SwiftUI

/// Acción protegida por el modo estricto.
struct GateAction: Identifiable {
    let id = UUID()
    let title: String
    let run: () -> Void
}

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: AlarmItem?
    @State private var creating = false
    @State private var gate: GateAction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    pipoGreeting
                    banners
                    if let next = model.nextAlarm {
                        NextAlarmCard(alarm: next.alarm, date: next.date)
                    }
                    alarmList
                    NightMessageCard()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $creating) {
                AlarmEditorView(alarm: nil)
            }
            .sheet(item: $editing) { alarm in
                AlarmEditorView(alarm: alarm)
            }
            .sheet(item: $gate) { action in
                StrictGateView(title: action.title) {
                    gate = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { action.run() }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            ScreenTitle("Mis alarmas")
            Button {
                creating = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.primary))
                    .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.deep).offset(y: 4))
            }
            .accessibilityLabel("Nueva alarma")
        }
    }

    private var pipoGreeting: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PipoView(mood: model.nextAlarm == nil ? .sleeping : .awake, accessory: model.state.equipped, size: 92)
            SpeechBubble(text: greeting)
        }
    }

    private var greeting: String {
        guard let next = model.nextAlarm else {
            return model.visibleAlarms.isEmpty
                ? "Crea una alarma y yo me encargo de despertarte."
                : "Todas las alarmas están apagadas. Me voy a echar la siesta."
        }
        return "\(Fmt.dayWord(next.date)) a las \(Fmt.time(next.date)) te despierto yo. Nada de posponer, ¿trato?"
    }

    @ViewBuilder
    private var banners: some View {
        if model.alarmAuth == .denied || model.alarmAuth == .notDetermined {
            WarningCard(
                icon: "alarm.waves.left.and.right",
                title: "Pipo no puede programar alarmas",
                text: model.alarmAuth == .denied
                    ? "Activa el permiso de Alarmas en Ajustes > Pipo."
                    : "Dale permiso para que la alarma suene aunque el móvil esté en silencio.",
                button: model.alarmAuth == .denied ? "Abrir Ajustes" : "Dar permiso"
            ) {
                if model.alarmAuth == .denied {
                    Permissions.openSettings()
                } else {
                    Task { await model.requestAlarmAuthorization() }
                }
            }
        }
        if let expiry = model.signingExpiry, expiry.timeIntervalSinceNow < 2 * 86400 {
            WarningCard(
                icon: "exclamationmark.arrow.triangle.2.circlepath",
                title: expiry > Date() ? "La app caduca en \(Fmt.until(expiry))" : "La firma de la app ha caducado",
                text: "Renuévala en SideStore. Si caduca, la alarma no sonará.",
                button: nil,
                action: nil
            )
        }
        if model.batteryLow {
            WarningCard(
                icon: "battery.25percent",
                title: "Batería baja",
                text: "Ponlo a cargar: con el móvil apagado no suena ninguna alarma.",
                button: nil,
                action: nil
            )
        }
    }

    private var alarmList: some View {
        VStack(spacing: 10) {
            ForEach(model.visibleAlarms) { alarm in
                AlarmRow(
                    alarm: alarm,
                    locked: model.isLocked(alarm),
                    onTap: { protect(alarm, "editar esta alarma") { editing = alarm } },
                    onToggle: { newValue in
                        if newValue {
                            model.setEnabled(alarm.id, true)
                        } else {
                            protect(alarm, "apagar esta alarma") { model.setEnabled(alarm.id, false) }
                        }
                    },
                    onDelete: { protect(alarm, "borrar esta alarma") { model.delete(alarm.id) } }
                )
            }
            if model.visibleAlarms.isEmpty {
                Button {
                    creating = true
                } label: {
                    Label("Crear mi primera alarma", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
        }
    }

    private func protect(_ alarm: AlarmItem, _ what: String, _ action: @escaping () -> Void) {
        if model.isLocked(alarm) {
            gate = GateAction(title: what, run: action)
        } else {
            action()
        }
    }
}

// MARK: - Tarjetas de inicio

struct NextAlarmCard: View {
    let alarm: AlarmItem
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Próxima alarma", color: Theme.onPrimary.opacity(0.8))
                Text(Fmt.time(date))
                    .font(Theme.clock(60))
                    .foregroundStyle(Theme.onPrimary)
                Text("Suena en \(Fmt.until(date)) · \(Fmt.days(alarm.weekdays))")
                    .font(Theme.body(.subheadline, .semibold))
                    .foregroundStyle(Theme.onPrimary)
                FlowChips(items: [
                    "Reto: \(Fmt.challenges(alarm))",
                    alarm.backupCount > 0 ? "Respaldos cada \(alarm.backupInterval) min" : "Sin respaldos"
                ])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.primary))
            .accessibilityElement(children: .combine)
        }
    }
}

private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(items, id: \.self) { item in
            Chip(text: item, fill: Theme.onPrimary.opacity(0.12), color: Theme.onPrimary)
        }
    }
}

struct AlarmRow: View {
    let alarm: AlarmItem
    let locked: Bool
    let onTap: () -> Void
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(Fmt.hm(alarm.hour, alarm.minute))
                            .font(Theme.clock(34))
                            .foregroundStyle(alarm.enabled ? Theme.text : Theme.muted)
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                                .accessibilityLabel("Bloqueada por el modo estricto")
                        }
                    }
                    Text("\(alarm.label) · \(Fmt.days(alarm.weekdays))")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                    Text("Reto: \(Fmt.challenges(alarm))")
                        .font(Theme.body(.footnote, .bold))
                        .foregroundStyle(alarm.enabled ? Theme.primaryText : Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("Activada", isOn: Binding(get: { alarm.enabled }, set: { onToggle($0) }))
                .labelsHidden()
                .tint(Theme.primary)
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .pipoCard()
        .contextMenu {
            Button("Editar", systemImage: "pencil", action: onTap)
            Button("Borrar", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

struct WarningCard: View {
    let icon: String
    let title: String
    let text: String
    let button: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.body(.body, .bold)).foregroundStyle(Theme.text)
                    Text(text).font(Theme.body(.subheadline)).foregroundStyle(Theme.muted)
                }
            }
            if let button, let action {
                Button(button, action: action)
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pipoCard(fill: Theme.surface2)
    }
}

struct NightMessageCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Mensaje para mañana")
            TextField("Escríbete algo para cuando te levantes", text: $model.state.nightMessage, axis: .vertical)
                .font(Theme.body(.body))
                .foregroundStyle(Theme.text)
                .lineLimit(1...3)
                .submitLabel(.done)
                .onChange(of: model.state.nightMessage) { _, _ in model.save() }
            Text("Te lo enseño cuando completes el reto.")
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pipoCard()
    }
}

// MARK: - Modo estricto

struct StrictGateView: View {
    let title: String
    let onPass: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PipoView(mood: .suspicious, size: 120)
                    Text("Modo estricto")
                        .font(Theme.display(.title, .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Para \(title) ahora tienes que resolver 8 cuentas. Así el tú de las 2:00 no te hace trampa.")
                        .font(Theme.body(.body))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    MathChallengeView(count: 8, hard: true, onDone: onPass)
                }
                .padding(20)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .tint(Theme.primaryText)
                }
            }
        }
    }
}
