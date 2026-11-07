import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var settings = env.settings
        NavigationStack {
            Form {
                Section {
                    Picker("自分の高さ", selection: $settings.scopeHeightSource) {
                        ForEach(ObserverHeightSource.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper(value: $settings.scopeHandHeight, in: 0...3, step: 0.1) {
                        HStack {
                            Text("手の高さ")
                            Spacer()
                            Text(String(format: "%.1fm", settings.scopeHandHeight)).monospacedDigit()
                        }
                    }
                    Toggle("高さを反映する", isOn: $settings.scopeUsesHeight)
                    Toggle("カメラ表示に向いている方角を出す", isOn: $settings.waypointShowsHeading)
                } header: {
                    Text("スコープ")
                } footer: {
                    Text("「地面の標高+手の高さ」は、国土地理院の標高APIで現在地の地面の標高を取ります(100m以上動いたときだけ、1回約70バイト)。取れないときは GPS の高度を使います。")
                }

                HeadingCorrectionSettingsSection()

                Section {
                    Toggle("Wi-Fi時のみ自動更新", isOn: $settings.wifiOnlyAutoRefresh)
                    LabeledContent("回線", value: env.network.summary)
                } header: {
                    Text("通信")
                } footer: {
                    Text("モバイル通信でも、軽いデータ(標高など)は自動で取ります。地形や航空写真などの重いデータは、Wi-Fi など従量制でない回線のときだけ保存します(v0.2 以降)。")
                }

                Section("受信量(今月)") {
                    LabeledContent("今日", value: Formatters.bytes(env.usage.today()))
                    LabeledContent("今月 Wi-Fi", value: Formatters.bytes(env.usage.thisMonth(.wifi)))
                    LabeledContent("今月 モバイル通信", value: Formatters.bytes(env.usage.thisMonth(.cellular)))
                    ForEach(UsageCategory.allCases, id: \.self) { category in
                        let bytes = env.usage.thisMonth(.wifi, category) + env.usage.thisMonth(.cellular, category)
                        if bytes > 0 {
                            LabeledContent("・\(category.label)", value: Formatters.bytes(bytes))
                        }
                    }
                }

                Section {
                    Toggle("方角のデバッグ表示", isOn: $settings.headingDebugEnabled)
                    Toggle("方角をジャイロで保つ(試験)", isOn: $settings.headingGyroHold)
                } header: {
                    Text("開発者向け")
                } footer: {
                    Text("方角のデバッグ表示は、カメラ表示に東西南北の印・水平線・仰角の目盛りと、センサーの値を重ねます。")
                }

                Section {
                    LabeledContent("バージョン", value: AppInfo.version)
                    Text(AppInfo.attribution)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("このアプリについて")
                }
            }
            .navigationTitle("設定")
        }
    }
}

enum AppInfo {
    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    /// 出典の表示(使っているデータが増えたら足す)
    static let attribution = "標高: 国土地理院 標高API(https://maps.gsi.go.jp/development/elevation_s.html)。地図: Apple マップ。スコープの計算は、同じ作者のスマートダッシュボード v0.9.33 から写したもの。"
}
