# 引き継ぎメモ

新しい会話で作業を続けるときは、まずこれを読む。方針は [CLAUDE.md](../CLAUDE.md)、データは [data-sources.md](data-sources.md)、設計は [design.md](design.md)、スコープのコピー元は [scope-origin.md](scope-origin.md)。

## 現在のバージョン

- **v0.1.0**(2026-11-07)。土台だけ
- 次は v0.2(避難場所)。design.md の「作る順番の提案」を参照

### v0.1.0 で作ったもの

- リポジトリ、XcodeGen のプロジェクト、アイコン、ci・release・apps.json の仕組み(スマートダッシュボード v0.9.33 から写した)
- スコープ: 地点の登録(現在地・地図をタップ・緯度経度)、標高の自動取得、表示・非表示、編集、削除、並べ替え。カメラ表示とコンパス表示(方角・距離・高低差)。方角の補正、方角のデバッグ表示
- 見る位置と向きの共通の型 `ScopeViewpoint`(カメラ表示と、これから作る幽体離脱で同じ計算を使うため)
- 受信量の記録(機能別: 標高、地形・航空写真、ハザードマップ、避難場所、地震・津波、その他)
- 写したが画面に出していないもの: 稜線の計算(`Skyline`、`TerrainGrid`)。v0.4 以降の水面・幽体離脱・稜線で使う
- データの調査(data-sources.md)と、設計の提案(design.md)

## 実装済みの機能(1行ずつ)

- 地点: `WaypointStore`(Application Support/BousaiScope/waypoints.json)、`WaypointListView`、`WaypointEditor`、`WaypointMapPicker`(SwiftUI の Map のタップ)
- 標高: `ElevationStore`(国土地理院の標高API、1回約70B。自分の地面の標高は100m以上動いたときだけ)
- カメラ表示・コンパス表示: `ScopeSightView`、`ScopeOverlay`(印を1枚の Canvas に)、`ScopeCompassDial`、`WaypointTracker`(位置・方位・CoreMotion)、`CameraController`
- 方角: `HeadingCorrection`(設定の「方角の補正」)、`HeadingDiagnostics`、`ScopeHeadingDebugView`、`ScopeCompassRoseOverlay`
- 通信: `MeteredHTTPClient`、`NetworkMonitor`、`RefreshPolicy`、`NetworkStatus.canDownloadHeavyData`、`DataUsageStore`
- 設定: `AppSettings`、`SettingsView`

## 実機での確認の状況

開発機は Windows で、Xcode も実機もない。ci で確かめられるのは、コンパイルとロジックのテストだけ。画面・センサー・カメラ・MapKit・LiveContainer での動作は、利用者の実機(iPhone SE 第2世代、LiveContainer)での報告に頼る。

### 利用者が実機で確認済み

- まだない

### まだ未確認

- LiveContainer に apps.json から入れられるか、起動するか
- 地点の登録(現在地・地図のタップ・緯度経度)と、標高の自動取得
- カメラ表示で、地点の方角・距離・高低差が実物と合うか(スマートダッシュボードと同じ計算なので、同じ見え方になるはず)
- 地図で選ぶ画面(スマートダッシュボードとは違い、SwiftUI の Map のタップで選ぶ。長押しではない)
- 設定の受信量の表示

## 未着手の予定

design.md の「作る順番の提案」のとおり。v0.2 避難場所、v0.3 地震と津波、v0.4 浸水の水面、v0.5 幽体離脱(歩く目線)、v0.6 自由な視点と建物、v0.7 稜線と緊急地震速報。

## コードを読んだだけでは分からない設計判断と、その理由

- **スコープは写して使う**: 共通のライブラリ(Swift Package)にはしなかった。XcodeGen と Actions の手間が増えるのと、2つのアプリの変更の時期が違うため。写したファイルはできるだけ中身を変えず、変えたものは scope-origin.md の「扱い」に書く。スマートダッシュボードで方角の直しが入ったら、表を見て当てる
- **型の名前は写したまま**(`Waypoint`、`WaypointTracker` など): 名前を変えると、コピー元の差分を当てにくくなるため。画面に出す名前だけを「地点」にしている
- **設定のキーもスマートダッシュボードと同じ**(`scope.headingOffset` など): Bundle ID が違うので、UserDefaults はぶつからない
- **`ScopeViewpoint`**: カメラ表示の位置の計算を、この型に通した。幽体離脱では、地図で選んだ点と仮想の向き(`CameraAttitude.looking`)から同じ型を作る。重ねる情報の計算をここだけにしておけば、幽体離脱で確かめた見え方が、カメラ表示でもそのまま正しい
  - 目の高さ(`eyeAltitude`)は、設定の「高さを反映する」がオフでも入れる(高低差の文字は出す)。印の上下の位置に使うかは、`targets(_:usesHeight:)` の引数で決める(スマートダッシュボードと同じ振る舞い)
- **地図で選ぶ画面は SwiftUI の Map**: スマートダッシュボードの地図(Wi-Fi では Apple Maps、モバイル通信では保存した地理院タイル)は、タイルの保存の仕組みごと持ってくる必要があり大きいので、v0.1.0 では写さなかった。Apple Maps の通信は iOS が行うので、受信量に数えられない
- **ホームのカード・ピン留めの操作は外した**: データの項目(`isPinned`)は残っている
- **画面の向きは縦だけ**(Info.plist): カメラ表示の計算が縦向きの前提のため

## 外部データの注意点

data-sources.md にまとめた。とくに:

- 気象庁の bosai の JSON は非公式。P2P地震情報は民間のサービス。どちらも「気象庁の発表」と発表元を出し、アプリが独自に「警報」と書かない
- ハザードのタイルの色は、凡例の色と完全に一致する(洪水・津波・高潮)。土砂災害は境界をなじませてあるので、alpha 255 の画素だけを一番近い色で分ける
- 避難場所のタイルは z10 だけで、gzip されない(1枚 350KB 前後)。Wi-Fi のときに取って、アプリの中で小さい形に直して持つ
- 地理院の利用上の注意(避難場所は最新でない場合がある、災害の種類ごとに指定されている)を画面で伝える

## 作業の進め方(要点)

- 調査 → 実装 → テスト → `python scripts/check_local.py` → docs の更新 → コミット → push → `gh workflow run ci.yml --ref main` を1回 → 成功したコミットにタグ → release と apps.json の反映を確認 → 報告
- v0.1.0 の Actions の実行: ci 2回(1回目は、写したテストが古い受信量の分類を使っていてコンパイルエラー)、release 1回
