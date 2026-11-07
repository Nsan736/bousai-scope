import Foundation

/// キャッシュするデータの種類と、最短の更新間隔
enum DataKind: String, CaseIterable, Codable {
    /// 国土地理院の標高(地点の標高、自分の高さ)。100m以上動いたときだけ取るので、間隔はない。
    case elevation
    /// 地震情報(v0.2 以降)
    case quake
    /// 津波警報・注意報(v0.2 以降)
    case tsunami

    var minimumInterval: TimeInterval {
        switch self {
        case .elevation: return 0
        case .quake: return 5 * 60
        case .tsunami: return 2 * 60
        }
    }

    var label: String {
        switch self {
        case .elevation: return "標高"
        case .quake: return "地震情報"
        case .tsunami: return "津波警報・注意報"
        }
    }
}

enum RefreshDecision: Equatable {
    case refresh
    case fresh
    case offline
    case blockedByConstrained
    case blockedByWiFiOnly
    case blockedByCellularLimit
}

/// 自動更新してよいかどうかを決める純関数。手動更新はオンラインなら常に許可する。
/// モバイル通信(従量制の回線)でも、最短の更新間隔を守ったうえで自動更新する。
/// 止めるのは、省データモード、「Wi-Fi時のみ」の設定、今月のモバイル通信量が上限を超えたとき。
struct RefreshPolicy {
    var wifiOnly: Bool
    /// 今月のモバイル通信量が、設定した上限を超えているか(上限の設定がオフなら常にfalse)
    var cellularLimitReached = false

    func autoDecision(kind: DataKind, fetchedAt: Date?, now: Date, network: NetworkStatus) -> RefreshDecision {
        if let fetchedAt, now.timeIntervalSince(fetchedAt) < kind.minimumInterval, fetchedAt <= now {
            return .fresh
        }
        guard network.isOnline else { return .offline }
        if network.isConstrained { return .blockedByConstrained }
        // テザリングのように、Wi-Fiでも従量制の回線はモバイル通信として扱う
        let isMobile = network.isExpensive || !network.isWiFi
        if wifiOnly && isMobile { return .blockedByWiFiOnly }
        if cellularLimitReached && isMobile { return .blockedByCellularLimit }
        return .refresh
    }

    func manualDecision(network: NetworkStatus) -> RefreshDecision {
        network.isOnline ? .refresh : .offline
    }
}

extension NetworkStatus {
    /// 重いデータ(タイル、避難場所の一覧)を自動で保存してよい回線か。従量制でも省データでもない回線(Wi-Fi など)だけ
    var canDownloadHeavyData: Bool {
        isOnline && !isExpensive && !isConstrained
    }
}
