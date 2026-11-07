# 防災スコープ(仮の名前)

iPhone 向けの防災アプリです。カメラの映像に方角・距離・高さを重ねる「スコープ」で、避難場所・浸水の想定・震源・津波警報などを直感的に見られるようにします。

- iOS 17 以上、SwiftUI。iPhone SE 第2世代を基準に軽く作っています
- 外では携帯回線で使う前提で、通信量を少なくしています(重いデータは Wi-Fi のときだけ保存)
- 署名なしの ipa を GitHub Actions で作り、AltStore 形式のソースで LiveContainer に入れて使います

## 入れ方(LiveContainer)

AltStore 形式のソースとして、次の URL を追加してください。

```
https://raw.githubusercontent.com/Nsan736/bousai-scope/main/apps.json
```

ipa だけが必要なときは https://github.com/Nsan736/bousai-scope/releases/latest/download/BousaiScope.ipa から取れます。

## できること(v0.1.0)

- 地点の登録(現在地、地図をタップ、緯度経度の入力)。標高は国土地理院の標高APIで自動で取ります
- カメラ表示: カメラの映像に、地点の方角・距離・高低差を重ねます(地球の丸みと大気の屈折を含めた高さ)
- コンパス表示: カメラが使えないときも、方角と距離を出します
- 方角の補正(磁気センサーがずれたとき)、方角のデバッグ表示
- 受信量の記録(機能別、Wi-Fi とモバイル通信別)

これからの予定は [docs/design.md](docs/design.md)、使うデータの調査は [docs/data-sources.md](docs/data-sources.md) にあります。

## 注意

- 浸水の深さ・津波の高さなどは、公的機関の「想定」や「予想」です。実際の災害はこれを超えることがあります。避難の判断は、市区町村や気象庁の発表に従ってください
- 開発者は実機を持たない Windows で開発しています。動作の報告をもとに直しています

## 出典

- 標高: 国土地理院 標高API(https://maps.gsi.go.jp/development/elevation_s.html)
- 地図(地点の登録): Apple マップ

使うデータが増えたら、ここと設定の「このアプリについて」に出典を足します。

## 開発

- XcodeGen(`project.yml`)でプロジェクトを作ります。`.xcodeproj` はコミットしません
- ビルドとテストは GitHub Actions(macOS)で行います。ci は手動実行(`gh workflow run ci.yml --ref main`)、`v*` のタグで release が ipa を作り、apps.json を更新します
- Actions を回す前に `python scripts/check_local.py` を通します
- スコープの部分は、同じ作者のスマートダッシュボード(https://github.com/Nsan736/smart-dashboard)v0.9.33 から写しました。ファイルの対応は [docs/scope-origin.md](docs/scope-origin.md)
- 開発の方針は [CLAUDE.md](CLAUDE.md)、引き継ぎは [docs/handoff.md](docs/handoff.md)
