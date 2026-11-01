import SwiftUI

@main
@MainActor
struct LiveTimerConnectApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task {
                    model.start()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.handleScenePhase(newPhase)
        }
    }
}
