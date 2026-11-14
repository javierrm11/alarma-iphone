import SwiftUI

struct AlarmEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AlarmItem
    @State private var time: Date
    @State private var confirmDelete = false
    private let isNew: Bool

    init(alarm: AlarmItem?) {
        let item = alarm ?? AlarmItem()
        isNew = alarm == nil
        _draft = State(initialValue: item)
        _time = State(initialValue: Calendar.current.date(bySettingHour: item.hour, minute: item.minute, second: 0, of: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    timeCard
                    labelField
                    daysSection
                    challengesSection
                    optionsCard
                    if !isNew {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Borrar alarma").foregroundStyle(Theme.primaryText)
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle(isNew ? "Nueva alarma" : "Editar alarma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.tint(Theme.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.bold)
                        .tint(Theme.primaryText)
                }
            }
            .confirmationDialog("¿Borrar esta alarma?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    model.delete(draft.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        draft.hour = comps.hour ?? 7
        draft.minute = comps.minute ?? 0
        if draft.label.trimmingCharacters(in: .whitespaces).isEmpty { draft.label = "Alarma" }
        if draft.challenges.isEmpty { draft.challenges = [.steps] }
        draft.enabled = true
        model.upsert(draft)
        dismiss()
    }

    // MARK: Secciones

    private var timeCard: some View {
        DatePicker("Hora", selection: $time, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Fmt.locale)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .pipoCard()
    }

    private var labelField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Nombre")
            TextField("Clase, gimnasio…", text: $draft.label)
                .font(Theme.body(.body, .semibold))
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .pipoCard(radius: Theme.smallRadius)
        }
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Repetir")
            HStack(spacing: 6) {
                ForEach(Fmt.weekOrder, id: \.weekday) { day in
                    let on = draft.weekdays.contains(day.weekday)
                    Button {
                        if on {
                            draft.weekdays.removeAll { $0 == day.weekday }
                        } else {
                            draft.weekdays.append(day.weekday)
                        }
                    } label: {
                        Text(day.letter)
                            .font(Theme.display(.headline, .bold))
                            .foregroundStyle(on ? Theme.onPrimary : Theme.text)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Theme.primary : Theme.surface2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.name)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text(draft.weekdays.isEmpty ? "Sonará una sola vez." : Fmt.days(draft.weekdays))
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.muted)
        }
    }

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Retos para apagarla")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(ChallengeKind.allCases) { kind in
                    challengeTile(kind)
                }
            }
            Text("Puedes elegir varios: se hacen en este orden.")
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.muted)

            if draft.challenges.contains(.steps) {
                Stepper(value: $draft.stepGoal, in: 20...1000, step: 10) {
                    Text("Pasos: \(draft.stepGoal)").font(Theme.body(.body, .semibold))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .pipoCard(radius: Theme.smallRadius)
            }
            if draft.challenges.contains(.math) {
                Stepper(value: $draft.mathCount, in: 3...20) {
                    Text("Cuentas: \(draft.mathCount)").font(Theme.body(.body, .semibold))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .pipoCard(radius: Theme.smallRadius)
            }
        }
    }

    private func challengeTile(_ kind: ChallengeKind) -> some View {
        let on = draft.challenges.contains(kind)
        return Button {
            if on {
                if draft.challenges.count > 1 { draft.challenges.removeAll { $0 == kind } }
            } else {
                draft.challenges.append(kind)
                draft.challenges = ChallengeKind.allCases.filter { draft.challenges.contains($0) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: kind.symbol)
                    .font(.title3)
                    .foregroundStyle(on ? Theme.primaryText : Theme.muted)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(Theme.body(.body, .bold))
                        .foregroundStyle(Theme.text)
                    Text(detail(kind))
                        .font(Theme.body(.caption))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                    .strokeBorder(on ? Theme.primary : Theme.line, lineWidth: on ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func detail(_ kind: ChallengeKind) -> String {
        switch kind {
        case .steps: return "\(draft.stepGoal) pasos"
        case .scan: return model.state.savedCode?.name ?? "Registra un código en Retos"
        case .math: return "\(draft.mathCount) operaciones"
        case .photo: return Persistence.hasReferencePhoto ? "Tu foto de referencia" : "Haz la foto en Retos"
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Para no volver a dormirte")
            VStack(spacing: 0) {
                Stepper(value: $draft.backupInterval, in: 1...10) {
                    rowText("Respaldos cada \(draft.backupInterval) min", "Y si deslizas para detenerla sin el reto, vuelve a sonar a los 30 s")
                }
                .padding(.horizontal, 16).frame(minHeight: 60)
                CardDivider()
                Stepper(value: $draft.backupCount, in: 0...30) {
                    rowText("Número de respaldos: \(draft.backupCount)", "Hasta \(draft.backupInterval * draft.backupCount) min después")
                }
                .padding(.horizontal, 16).frame(minHeight: 60)
                CardDivider()
                Toggle(isOn: $draft.awakeCheck) {
                    rowText("¿Sigues despierto?", "Te pregunto a los 5 y a los 10 min")
                }
                .tint(Theme.primary)
                .padding(.horizontal, 16).frame(minHeight: 60)
                CardDivider()
                Toggle(isOn: $draft.strict) {
                    rowText("Modo estricto", "En las 10 h anteriores, apagarla o cambiarla pide 8 cuentas")
                }
                .tint(Theme.primary)
                .padding(.horizontal, 16).frame(minHeight: 60)
            }
            .pipoCard()
            Text(model.state.customSound.map { "Suena con \"\($0.title)\" (\($0.rangeText)). Cámbialo en Ajustes." } ?? "Suena con el sonido de alarma del sistema. Puedes poner una canción en Ajustes.")
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.muted)
        }
    }

    private func rowText(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.body(.body, .semibold)).foregroundStyle(Theme.text)
            Text(subtitle).font(Theme.body(.caption)).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 6)
    }
}
