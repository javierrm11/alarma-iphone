import SwiftUI

/// Pantalla 8: racha, tiempos y armario de Pipo.
struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenTitle("Progreso")
                    streakCard
                    barsCard
                    summaryCard
                    wardrobe
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var streakCard: some View {
        let streak = model.currentStreak()
        let days = model.recentDays()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(streak == 1 ? "1 día seguido" : "\(streak) días seguidos")
                        .font(Theme.display(.title3, .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Récord: \(model.bestStreak()) días")
                        .font(Theme.body(.subheadline))
                        .foregroundStyle(Theme.muted)
                }
            }
            if days.isEmpty {
                Text("Aquí verás tus mañanas en cuanto suene la primera alarma.")
                    .font(Theme.body(.subheadline))
                    .foregroundStyle(Theme.muted)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 4) {
                            Image(systemName: day.ok ? "checkmark" : "xmark")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(day.ok ? Theme.onPrimary : Theme.muted)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 10).fill(day.ok ? Theme.primary : Theme.surface2))
                            Text(day.letter)
                                .font(Theme.body(.caption, .bold))
                                .foregroundStyle(Theme.muted)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(day.letter), \(day.ok ? "superado" : "fallado")")
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pipoCard()
    }

    private var barsCard: some View {
        let bars = model.lastWeekBars()
        let maxMinutes = max(5, bars.compactMap(\.minutes).max() ?? 5)
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Minutos hasta completar el reto")
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(bars) { bar in
                    VStack(spacing: 4) {
                        Text(bar.minutes.map(String.init) ?? "–")
                            .font(Theme.body(.caption, .bold))
                            .foregroundStyle(bar.isToday ? Theme.primaryText : Theme.muted)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(bar.isToday ? Theme.primary : Theme.primary.opacity(0.35))
                            .frame(height: CGFloat(bar.minutes ?? 0) / CGFloat(maxMinutes) * 100 + 4)
                        Text(bar.letter)
                            .font(Theme.body(.caption, .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(height: 140, alignment: .bottom)
        }
        .padding(16)
        .pipoCard()
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            InfoRow(title: "Hora media real de levantarte") {
                Text(model.averageWakeTime ?? "–").font(Theme.body(.body, .bold)).foregroundStyle(Theme.primaryText)
            }
            CardDivider()
            InfoRow(title: "Respaldos que sonaron (7 días)") {
                Text("\(model.backupsThisWeek)").font(Theme.body(.body, .bold)).foregroundStyle(Theme.primaryText)
            }
            CardDivider()
            InfoRow(title: "Mañanas sin completar el reto (7 días)") {
                Text("\(model.missedThisWeek)").font(Theme.body(.body, .bold)).foregroundStyle(Theme.primaryText)
            }
        }
        .pipoCard()
    }

    private var wardrobe: some View {
        let unlockedCount = Accessory.allCases.filter { model.isUnlocked($0) }.count
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Armario de Pipo · \(unlockedCount)/\(Accessory.allCases.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Accessory.allCases) { item in
                    let unlocked = model.isUnlocked(item)
                    let equipped = model.state.equipped == item
                    Button {
                        if unlocked { model.equip(equipped ? nil : item) }
                    } label: {
                        VStack(spacing: 6) {
                            PipoView(mood: .happy, accessory: item, size: 46, animated: false)
                                .opacity(unlocked ? 1 : 0.35)
                            Text(unlocked ? item.name : "Racha de \(item.streakNeeded)")
                                .font(Theme.body(.caption2, .bold))
                                .foregroundStyle(unlocked ? Theme.text : Theme.muted)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: 104)
                        .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(unlocked ? Theme.surface : Color.clear))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.smallRadius)
                                .strokeBorder(equipped ? Theme.primary : Theme.line,
                                              style: StrokeStyle(lineWidth: equipped ? 3 : 2, dash: unlocked ? [] : [5, 4]))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    .accessibilityLabel(unlocked ? "\(item.name)\(equipped ? ", puesto" : "")" : "\(item.name), bloqueado: racha de \(item.streakNeeded) días")
                }
            }
            Text("Toca un accesorio desbloqueado para ponérselo a Pipo.")
                .font(Theme.body(.caption))
                .foregroundStyle(Theme.muted)
        }
    }
}
