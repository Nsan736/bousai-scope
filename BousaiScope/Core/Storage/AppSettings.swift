import Foundation
import Observation

/// 設定(UserDefaults)。スマートダッシュボードの AppSettings から、スコープと通信量の項目だけを持ってきた。
/// キーの名前は、スマートダッシュボードと同じにしてある(どちらのアプリの設定かは、Bundle ID で分かれる)。
@MainActor
@Observable
final class AppSettings {
    /// モバイル通信では自動更新しない(初期値オフ)
    var wifiOnlyAutoRefresh: Bool {
        didSet { defaults.set(wifiOnlyAutoRefresh, forKey: Keys.wifiOnlyAutoRefresh) }
    }

    /// カメラ表示の上部に、向いている方角を出す
    var waypointShowsHeading: Bool {
        didSet { defaults.set(waypointShowsHeading, forKey: Keys.waypointShowsHeading) }
    }

    /// 高さを反映する(印の上下の位置)
    var scopeUsesHeight: Bool {
        didSet { defaults.set(scopeUsesHeight, forKey: Keys.scopeUsesHeight) }
    }

    var scopeHeightSource: ObserverHeightSource {
        didSet { defaults.set(scopeHeightSource.rawValue, forKey: Keys.scopeHeightSource) }
    }

    /// 手の高さ(m、地面から)。初期値1.5m
    var scopeHandHeight: Double {
        didSet { defaults.set(scopeHandHeight, forKey: Keys.scopeHandHeight) }
    }

    /// 方角の補正(度、−180〜180、時計回りが正)。端末の方角を使うすべての所に足す(`HeadingCorrection`)
    var headingOffset: Double {
        didSet {
            let normalized = HeadingCorrection.normalized(headingOffset)
            defaults.set(normalized, forKey: HeadingCorrection.defaultsKey)
            HeadingCorrection.current = normalized
        }
    }

    /// 東西南北の印と水平線、仰角の目盛りを、カメラ表示に重ねる(開発者向け)
    var headingDebugEnabled: Bool {
        didSet { defaults.set(headingDebugEnabled, forKey: Keys.headingDebugEnabled) }
    }

    /// 方角をジャイロで保つ(試験。開発者向け)
    var headingGyroHold: Bool {
        didSet { defaults.set(headingGyroHold, forKey: Keys.headingGyroHold) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        wifiOnlyAutoRefresh = defaults.bool(forKey: Keys.wifiOnlyAutoRefresh)
        waypointShowsHeading = defaults.object(forKey: Keys.waypointShowsHeading) as? Bool ?? true
        scopeUsesHeight = defaults.object(forKey: Keys.scopeUsesHeight) as? Bool ?? true
        scopeHeightSource = defaults.string(forKey: Keys.scopeHeightSource).flatMap(ObserverHeightSource.init(rawValue:)) ?? .groundPlusHand
        scopeHandHeight = defaults.object(forKey: Keys.scopeHandHeight) as? Double ?? 1.5
        headingDebugEnabled = defaults.bool(forKey: Keys.headingDebugEnabled)
        headingGyroHold = defaults.bool(forKey: Keys.headingGyroHold)
        let offset = HeadingCorrection.normalized(defaults.double(forKey: HeadingCorrection.defaultsKey))
        headingOffset = offset
        HeadingCorrection.current = offset
    }

    var refreshPolicy: RefreshPolicy {
        RefreshPolicy(wifiOnly: wifiOnlyAutoRefresh)
    }

    private enum Keys {
        static let wifiOnlyAutoRefresh = "refresh.wifiOnly"
        static let waypointShowsHeading = "waypoint.showsHeading"
        static let scopeUsesHeight = "scope.usesHeight"
        static let scopeHeightSource = "scope.heightSource"
        static let scopeHandHeight = "scope.handHeight"
        static let headingDebugEnabled = "scope.headingDebug"
        static let headingGyroHold = "scope.headingGyroHold"
    }
}
