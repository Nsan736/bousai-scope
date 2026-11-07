import CoreLocation
import Foundation
import Observation
import UIKit

enum SensorAvailability: Equatable {
    case unknown
    case available
    case denied
    case unsupported

    var unavailableText: String? {
        switch self {
        case .unknown, .available: return nil
        case .denied: return "利用不可(権限なし)"
        case .unsupported: return "利用不可(この環境では使えません)"
        }
    }
}

/// 画面を消さない指定を、理由ごとにまとめて管理する(タイマーとセンサー画面が互いに打ち消さないようにする)
@MainActor
enum ScreenAwake {
    private static var reasons: Set<String> = []

    static func set(_ reason: String, _ isOn: Bool) {
        if isOn { reasons.insert(reason) } else { reasons.remove(reason) }
        UIApplication.shared.isIdleTimerDisabled = !reasons.isEmpty
    }
}
