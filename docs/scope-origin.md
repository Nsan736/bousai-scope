# スコープのコピー元

スコープの部分は、同じ作者の「スマートダッシュボード」(https://github.com/Nsan736/smart-dashboard 、公開)から写した。同じ作者なので、ライセンス上の問題はない。

- コピー元: **v0.9.33**(タグのコミット `ca8b4c842c7a649cef44e491944b374e398d2241`、2026-10-19)
  - 写した時点の main は `647563e`(v0.9.33 のあとに apps.json だけを更新したもの。Swift のソースはタグと同じ)
- 写した日: 2026-11-07
- コピー元の直し(方角のずれの調査など)を取り込むときは、下の表の「扱い」を見て、そのまま写したファイルは差分をそのまま当て、手を入れたファイルは中身を見て合わせる

## ファイルの対応

扱い: **そのまま** = 中身を変えていない(テストの `@testable import` の名前だけ変えたものを含む)。**一部** = 一部だけを切り出した。**手直し** = 防災スコープに合わせて変えた。

| 防災スコープのファイル | コピー元(SmartDashboard/ の下) | 扱い |
|---|---|---|
| `BousaiScope/Scope/Geometry/WaypointModels.swift` | Features/Scope/WaypointModels.swift | そのまま(方位・距離、地球の丸みと屈折、端末の向き、画面上の位置の計算) |
| `BousaiScope/Scope/Geometry/ScopeModels.swift` | Features/Scope/ScopeModels.swift | 一部(ScopeMark、ScopeTarget)+ 追加(ScopeViewpoint、CameraAttitude.looking) |
| `BousaiScope/Scope/Geometry/HeadingCorrection.swift` | Features/Scope/HeadingCorrection.swift | そのまま(方角の手動補正) |
| `BousaiScope/Scope/Geometry/HeadingDiagnostics.swift` | Features/Scope/HeadingDiagnostics.swift | そのまま(方角の診断、位置の誤差による方向のずれ) |
| `BousaiScope/Scope/Geometry/GeoPoint.swift` | Features/Train/RideGeometry.swift | 一部(GeoPoint、GeoMath) |
| `BousaiScope/Scope/Sensors/WaypointTracker.swift` | Features/Scope/WaypointTracker.swift | そのまま(位置・方位・CoreMotion、カメラ) |
| `BousaiScope/Scope/Sensors/SensorAvailability.swift` | Features/Sensors/LocationSensors.swift | 一部(SensorAvailability、ScreenAwake) |
| `BousaiScope/Scope/Terrain/TerrainGrid.swift` | Features/Scope/Scenery/TerrainGrid.swift | そのまま(標高タイルの読み取り、距離ごとのズーム) |
| `BousaiScope/Scope/Terrain/Skyline.swift` | Features/Scope/Scenery/Skyline.swift | そのまま(稜線の計算。v0.1.0 では画面に出していない) |
| `BousaiScope/Scope/Views/ScopeSightView.swift` | Features/Scope/ScopeSightView.swift | 手直し(地点だけ。周辺・経路・電車・景色・オブジェクト・太陽と月・撮って聞くを外し、位置の計算を ScopeViewpoint に通した) |
| `BousaiScope/Scope/Views/ScopeCompassDial.swift` | Features/Scope/ScopeSightView.swift | 一部(ScopeCompassDial) |
| `BousaiScope/Scope/Views/ScopeCompassRose.swift` | Features/Scope/ScopeCompassRose.swift | そのまま(東西南北の印と水平線、仰角の目盛り) |
| `BousaiScope/Scope/Views/ScopeHeadingCorrectionViews.swift` | Features/Scope/ScopeHeadingCorrectionViews.swift | 手直し(説明の文だけ) |
| `BousaiScope/Scope/Views/ScopeHeadingDebugView.swift` | Features/Scope/ScopeHeadingDebugView.swift | そのまま(コメント1行だけ) |
| `BousaiScope/Scope/Places/WaypointStore.swift` | Features/Scope/WaypointStore.swift | そのまま |
| `BousaiScope/Scope/Places/ElevationStore.swift` | Features/Scope/ElevationStore.swift | 手直し(回線の判定を `NetworkStatus.canDownloadHeavyData` に) |
| `BousaiScope/Scope/Places/WaypointListView.swift` | Features/Scope/WaypointListView.swift | 手直し(経路とピン留めを外し、地図での登録を SwiftUI の Map のタップに) |
| `BousaiScope/Core/Network/HTTPClient.swift` | Core/Network/HTTPClient.swift | そのまま(コメントだけ) |
| `BousaiScope/Core/Network/NetworkMonitor.swift` | Core/Network/NetworkMonitor.swift | そのまま |
| `BousaiScope/Core/Network/DataUsageStore.swift` | Core/Network/DataUsageStore.swift | 手直し(機能の分類を防災のデータに) |
| `BousaiScope/Core/Cache/RefreshPolicy.swift` | Core/Cache/RefreshPolicy.swift | 手直し(データの種類) |
| `BousaiScope/Core/Location/LocationProvider.swift` | Features/Weather/LocationProvider.swift | そのまま |
| `BousaiScope/Core/Util/KeyboardDismiss.swift` | Core/Util/KeyboardDismiss.swift | そのまま |
| `BousaiScope/Core/Util/Formatters.swift` | Core/Util/Formatters.swift | そのまま |

テスト: `BousaiScopeTests/` の HeadingTests・WaypointTests はそのまま、WaypointHeightTests は受信量の分類の2行だけを新しい分類に替え、ProjectionTests は電車・山・オブジェクトの比べ合わせを ScopeViewpoint のテストに替え、SkylineTests は SceneryTests から稜線と地形の分だけを写した。

ワークフロー(`.github/workflows/`)、`scripts/make_apps_json.py`、`scripts/check_local.py`、`.gitignore`、`.gitattributes` も、スマートダッシュボード v0.9.33 から写して名前を変えた。
