import Foundation
import Observation

/// アプリ全体で共有する依存をまとめる
@MainActor
@Observable
final class AppEnvironment {
    let settings: AppSettings
    let network: NetworkMonitor
    let usage: DataUsageStore
    let waypoints: WaypointStore
    /// 地点の標高と、自分の地面の標高(国土地理院の標高API)
    let elevation: ElevationStore
    /// 背面カメラ。セッションの設定を使い回すため、アプリ全体で1つ。
    let camera = CameraController()
    @ObservationIgnored let http: HTTPClient
    @ObservationIgnored let location: LocationProvider

    init() {
        let settings = AppSettings()
        let network = NetworkMonitor()
        let directory = Self.dataDirectory()
        let usage = DataUsageStore(fileURL: directory.appendingPathComponent("usage.json"))
        let http = MeteredHTTPClient { [weak usage] record in
            Task { @MainActor in usage?.add(record) }
        }
        let waypoints = WaypointStore(fileURL: directory.appendingPathComponent("waypoints.json"))
        let elevation = ElevationStore(http: http, network: network, settings: settings, waypoints: waypoints) { _ in }
        self.settings = settings
        self.network = network
        self.usage = usage
        self.http = http
        self.waypoints = waypoints
        self.elevation = elevation
        location = LocationProvider()
        waypoints.onNeedsElevation = { [weak elevation] id in
            Task { await elevation?.fetchElevation(for: id) }
        }
    }

    /// Application Support/BousaiScope(なければ作る)
    static func dataDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("BousaiScope", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
