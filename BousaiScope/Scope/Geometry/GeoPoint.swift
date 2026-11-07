import CoreLocation
import Foundation

/// 緯度経度の点(保存・比較しやすいように、CLLocationCoordinate2D の代わりに使う)
struct GeoPoint: Codable, Equatable, Hashable {
    var latitude: Double
    var longitude: Double

    init(_ latitude: Double, _ longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(coordinate.latitude, coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    enum CodingKeys: String, CodingKey {
        case latitude = "a"
        case longitude = "o"
    }
}

/// 数km程度の範囲の計算。原点のまわりを平面とみなす(誤差は数kmで0.1%未満)。
enum GeoMath {
    static let earthRadius = 6_371_000.0

    /// 2点間の距離(m)
    static func distance(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let p = local(b, origin: a)
        return (p.x * p.x + p.y * p.y).squareRoot()
    }

    /// origin を原点にした平面の座標(m)。x は東、y は北。
    static func local(_ point: GeoPoint, origin: GeoPoint) -> (x: Double, y: Double) {
        let latitude = (point.latitude + origin.latitude) / 2 * .pi / 180
        let x = (point.longitude - origin.longitude) * .pi / 180 * earthRadius * cos(latitude)
        let y = (point.latitude - origin.latitude) * .pi / 180 * earthRadius
        return (x, y)
    }

    /// origin から東へ east m、北へ north m ずらした点
    static func offset(_ origin: GeoPoint, east: Double, north: Double) -> GeoPoint {
        let latitude = origin.latitude + north / earthRadius * 180 / .pi
        let middle = (latitude + origin.latitude) / 2 * .pi / 180
        let longitude = origin.longitude + east / (earthRadius * cos(middle)) * 180 / .pi
        return GeoPoint(latitude, longitude)
    }
}
