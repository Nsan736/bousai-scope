import SwiftUI

@main
struct BousaiScopeApp: App {
    @State private var env = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(env)
                .task { env.network.start() }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard phase == .active else { return }
                    // 標高が未設定の地点(オフラインで登録した地点など)は、Wi-Fi など従量制でない回線のときに取る
                    Task { await env.elevation.fillMissing() }
                }
        }
    }
}
