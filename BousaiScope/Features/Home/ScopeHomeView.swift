import SwiftUI

/// スコープのタブ。v0.1.0 は登録した地点の一覧と、カメラ表示・コンパス表示。
struct ScopeHomeView: View {
    var body: some View {
        NavigationStack {
            WaypointListView()
                .navigationTitle("防災スコープ")
        }
    }
}
