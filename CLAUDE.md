# 防災スコープ(仮の名前)

iPhone 向けの防災アプリ。カメラの映像に方角・距離・高さを重ねる「スコープ」で、避難場所・浸水の想定・震源・津波警報などを直感的に見る。SwiftUI 製。AltStore 形式のソース(apps.json)で LiveContainer に入れて使う。有料の開発者アカウントは使わない。

- リポジトリ: https://github.com/Nsan736/bousai-scope (公開)
- Bundle ID: `com.nsan.bousaiscope` / 表示名: 防災スコープ
- iOS 17以上。Swift、SwiftUI、Swift Concurrency、Observation
- 外部SDK・ライブラリは使わない(Swift標準とApple純正フレームワークのみ)
- プロジェクトはXcodeGen(`project.yml`)で生成する。`.xcodeproj` はコミットしない
- 方針は、同じ作者の「スマートダッシュボード」(https://github.com/Nsan736/smart-dashboard)を引き継いでいる。スコープの部分はそこから写した(コピー元の版と、ファイルの対応は [docs/scope-origin.md](docs/scope-origin.md))

## 現在の状況と引き継ぎ

- 最新のリリースは **v0.1.0**(2026-11-07)。土台だけ: 地点を登録して、カメラ表示とコンパス表示で方角・距離・高低差を見る
- 新しい会話で作業を続けるときは、まず [docs/handoff.md](docs/handoff.md) を読む(実装済みの機能、実機で確認済みかどうか、次の予定、設計判断の理由)
- 使えるデータの調査は [docs/data-sources.md](docs/data-sources.md)、これから作るものの設計は [docs/design.md](docs/design.md)
- 開発機は Windows で実機がない。画面・センサー・カメラ・MapKit の動作は、利用者の報告に頼る。未確認のものを「動く」と書かない
- 機能を足したり、実機の報告を受けたりしたら、docs/handoff.md も更新する
- 版は 0.x で進める。1.0.0 は利用者が判断したときに付ける

## 最重要方針: 通信量を少なくする

外では携帯回線で使う前提。

- 起動時とフォアグラウンド復帰時に、キャッシュが古いものだけを取得する。定期ポーリングはしない(地震・津波も、画面を開いたときと手動更新だけ)
- **重いデータ(地形・航空写真・建物・ハザードのタイル、避難場所の一覧)は、Wi-Fi など従量制でない回線のときだけ保存する**(`NetworkStatus.canDownloadHeavyData`)。モバイル通信では保存済みの範囲だけで表示し、その旨を出す
- 軽いデータ(標高API 1回約70B、地震の一覧など)は、モバイル通信でも最短の更新間隔を守って自動で取る。止めるのは省データモード、設定「Wi-Fi時のみ自動更新」のとき(`RefreshPolicy`)
- 取得結果はタイムスタンプ付きでディスクに保存する。オフライン時は「◯分前の情報」と明示する
- APIリクエストは必要な範囲だけに絞る
- 画像・Webフォント・リモートのアイコンは取得しない(地図タイルを除く)。アイコンは SF Symbols のみ
- 通信は必ず `HTTPClient` プロトコル(本番は `MeteredHTTPClient`)を経由する。`URLSession.shared` を直接使わない。受信量は機能別(`UsageCategory`)に記録して設定画面に出す
- 避難場所の方角と距離は、保存したデータだけで出せるようにする(圏外でも使える)

## 防災の情報の扱い

- 浸水の深さ・津波の高さ・土砂災害の区域は「想定」であることを、画面ではっきり示す(色・文字・出典。docs/design.md の「想定の示し方」)。実際の浸水や、避難の判断の保証のように見せない
- 気象庁の bosai の JSON は非公式(仕様の公開がなく、予告なく変わりうる)。P2P地震情報は気象庁の情報を中継する民間のサービス。どちらも「公式の発表を確かめる」導線を付ける
- 出典の表示が必要なデータ(国土地理院、気象庁、PLATEAU、OpenStreetMap など)は、使う画面と設定の「このアプリについて」に出典を書く

## LiveContainer での制約

- ウィジェット、Live Activity、App Extension、プッシュ通知(APNs)、バックグラウンド更新は使わない
- バックグラウンドでの位置情報は使わない(LiveContainer ではアプリの Info.plist が効かないことがあり、allowsBackgroundLocationUpdates で落ちるため)
- 緊急地震速報の WebSocket は、アプリを開いている間だけつなぐ(バックグラウンドでは受け取れないことを画面で示す)
- 位置・モーション・カメラの権限が取れなくてもクラッシュさせず、「利用不可」と表示し、他の機能は使えるようにする

## 軽さの基準

- iPhone SE 第2世代(A13、メモリ 3GB、4.7 インチ 375×667pt)で軽く動くこと
- カメラ・GPS・モーションは、カメラ表示を開いている間だけ動かす(`WaypointTracker`、`CameraController`)
- 重ねる印は1枚の Canvas にまとめて描く。計算の重いもの(稜線、水面の格子)は、位置が一定以上動いたときだけメインスレッドの外で計算する

## スコープの計算(カメラ表示と幽体離脱で共通)

- 方角・距離・仰角・画面上の位置は、`ScopeViewpoint`(見る位置・目の高さ・向き・画角)だけを通して計算する。カメラ表示は実際の端末の向き、幽体離脱は仮想の向きを入れる。幽体離脱で確かめた見え方が、カメラ表示でもそのまま正しくなるようにするため
- 仰角は地球の丸みと大気の屈折を含める(`WaypointElevation.angle`、屈折の係数 0.13)
- 基準の座標系は x=真北、y=西、z=上(CMAttitudeReferenceFrame.xTrueNorthZVertical)。方角の手動補正(`HeadingCorrection`)を、端末の方角を使う所すべてに足す
- 写したスコープのファイルは、できるだけ中身を変えずに使う(コピー元の直しを取り込みやすくするため)。変えたものは docs/scope-origin.md の表の「扱い」を直す

## 画面構成(v0.1.0)

- スコープ(`ScopeHomeView` → `WaypointListView`): 地点の登録(現在地、地図をタップ、緯度経度の入力)、表示・非表示、編集、削除、並べ替え。「カメラで見る」「コンパスで見る」(`ScopeSightView`)
- 設定(`SettingsView`): 自分の高さ、方角の補正、Wi-Fi時のみ自動更新、受信量、開発者向け(方角のデバッグ表示)、出典

## 入力とレイアウト

- 入力欄のある画面には `.keyboardDismissable()` を付ける。入力欄の外のタップで閉じる処理は `KeyboardTapDismissInstaller` がアプリ全体で1つ受け持つ
- 基準は最小の画面幅(320〜375pt)と、文字サイズを1〜2段階大きくした場合。数値は lineLimit(1) と minimumScaleFactor、文章は省略せず折り返す

## 永続化

- 設定: UserDefaults
- 地点・受信量: Application Support/BousaiScope 以下に JSON
- タイルなどの保存データ(v0.2 以降): Application Support/BousaiScope/tiles/種類/z/x/y

## 秘密情報

トークンなどの秘密情報は絶対にコミットしない。フィクスチャにも含めない。`.gitignore` を維持する。check_local.py がトークンらしき文字列を探す。private/ は Git の管理外。

## テスト

- APIクライアントはプロトコルで抽象化する
- JSONデコードのユニットテストを用意する。フィクスチャは実際のレスポンスを小さく切り詰めたもの
- `@MainActor` なクラスの静的メンバーをテストから呼ぶときは、`nonisolated static` にするか、テスト側を `@MainActor` にする
- View に準拠した型は全体が `@MainActor` になる。テストしたいロジックは View の外(enum など)に置く
- ci のテスト先は画面の小さい iPhone SE を優先する
- テストに使うスレッド・並列数は12まで(ci は `-parallel-testing-enabled NO`)

## ビルドと検証(GitHub Actions)

開発機は Windows で Xcode がないため、ビルドとテストの検証は GitHub Actions で行う。Actions は「macOS でしかできないこと」だけに使い、回数を最小にする(公開リポジトリなので標準のランナーは無料だが、待ち時間を減らすため)。

### ワークフロー

- `.github/workflows/ci.yml`: ビルドとテスト。トリガーは手動実行(workflow_dispatch)と pull_request だけ。main への push では動かさない
  - 1つのジョブで、シミュレーターでのテスト(起動は1回)と、実機向けの署名なしコンパイル確認を行う
  - paths-ignore で、ドキュメント(*.md)、apps.json、scripts などだけの変更では動かさない
- `.github/workflows/release.yml`: タグ `v*` の push だけで動く。`xcodebuild -sdk iphoneos CODE_SIGNING_ALLOWED=NO` → `Payload/BousaiScope.app` を zip して `BousaiScope.ipa` → GitHub Releases → `apps.json` を更新して main に直接コミット。テストはしないので、ci が成功したコミットにだけタグを付ける
- 共通: macos-15、Xcode は明示的に選ぶ(現在 16.4)。XcodeGen は `HOMEBREW_NO_AUTO_UPDATE=1` で brew から入れる。concurrency の cancel-in-progress: true、timeout-minutes: 20
- ipa のファイル名は固定(`BousaiScope.ipa`)。`releases/latest/download/BousaiScope.ipa` でも取得できる
- AltStore のソース: https://raw.githubusercontent.com/Nsan736/bousai-scope/main/apps.json

### 実行の回数

- コミットは細かく分けてよいが、push と ci の実行は「段階の区切り」ごとに1回だけにする
- 実行は手動: `gh workflow run ci.yml --ref main`
- 実行する前に、Swift の文法や型の誤り、Info.plist・project.yml の整合性を、コードを読んで自分で確認する
- 実行する前に `python scripts/check_local.py` を通す
- 失敗したときは `gh run view --log-failed` でログから原因をまとめて特定し、関連する修正を1回で直してから再実行する
- 段階の報告には、その段階で Actions を何回実行したかを書く

## 進め方

- 1回の区切りの流れ: 調査(必要なら実データで確認)→ 実装 → ユニットテスト → `python scripts/check_local.py` → CLAUDE.md・README・docs/handoff.md の更新 → 項目ごとにコミット → push → ci を1回 → 成功したコミットにタグ → release と apps.json の反映を確認 → 報告(実機で見てほしい点と、Actions の回数を含める)
- 依頼の内容と実際のデータが食い違うとき(URL が古い、指定が矛盾している、など)は、採った扱いと理由を報告に書く

## コミットメッセージ

- Conventional Commits 形式、本文は日本語。例: `feat: 避難場所の方角を表示` / `fix: 浸水の深さの読み取りを修正`
- 種類: feat / fix / refactor / test / ci / docs / chore
- 1コミットには1つのまとまった変更だけを入れる
- ワークフローによる apps.json の自動更新コミットは `chore: apps.json を v1.2.3 に更新 [skip ci]` の形にする

## コードの書き方

- コメントは日本語。絵文字は使わない(UI にも使わない)
- 表示は日本語。ダークモード対応。主要な数値は大きく表示する
