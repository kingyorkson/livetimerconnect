import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                TimersView()
                    .tabItem {
                        Label("Timers", systemImage: "timer")
                    }

                AlarmsView()
                    .tabItem {
                        Label("Alarms", systemImage: "alarm.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .tint(AppTheme.orange)

            if let toast = model.toast {
                ToastView(message: toast)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 74)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(5)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: model.toast)
    }
}
