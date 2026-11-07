import SwiftUI

/// 画面の構成(v0.1.0): スコープ(地点の一覧とカメラ表示)と設定
struct RootTabView: View {
    var body: some View {
        TabView {
            ScopeHomeView()
                .tabItem { Label("スコープ", systemImage: "scope") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .background(KeyboardTapDismissInstaller())
    }
}
