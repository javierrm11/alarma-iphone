import SwiftUI
import Combine

@main
struct PipoApp: App {
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await model.refresh() }
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    private let ticker = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var model = model
        Group {
            if model.state.onboardingDone {
                TabView {
                    Tab("Alarmas", systemImage: "alarm") { HomeView() }
                    Tab("Retos", systemImage: "trophy") { ChallengesView() }
                    Tab("Progreso", systemImage: "chart.bar") { StatsView() }
                    Tab("Ajustes", systemImage: "slider.horizontal.3") { SettingsView() }
                }
                .tint(Theme.primaryText)
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: $model.route) { route in
            switch route {
            case .session(let alarmID, let occurrence):
                WakeFlowView(alarmID: alarmID, occurrence: occurrence)
                    .environment(model)
            case .check(let id):
                AwakeCheckView(checkID: id)
                    .environment(model)
            }
        }
        .onReceive(ticker) { _ in
            model.updateBattery()
            model.detectRoute()
        }
        .preferredColorScheme(.light)
        .fontDesign(.rounded)
    }
}
