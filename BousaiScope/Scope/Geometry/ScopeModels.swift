import Foundation
import SwiftUI

/// カメラ表示とコンパス表示に出す印(登録した地点。これから避難場所・震源・津波の沿岸なども同じ形にそろえる)
struct ScopeMark: Equatable, Identifiable {
    var id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var color: Color
    /// 高さ(m、標高+地面からの高さ)。分からなければ nil(地平線の高さに置く)。
    var altitude: Double?
    /// 進行方向(度)。コンパス表示で、矢印の印にする。地上の動かない印では nil。
    var travelHeading: Double? = nil
    /// 名前の下に添える短い説明
    var note = ""

    init(id: String, name: String, latitude: Double, longitude: Double, color: Color, altitude: Double? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.color = color
        self.altitude = altitude
    }

    init(_ waypoint: Waypoint) {
        self.init(id: waypoint.id.uuidString, name: waypoint.name, latitude: waypoint.latitude, longitude: waypoint.longitude,
                  color: WaypointPalette.color(waypoint.colorIndex), altitude: waypoint.altitude)
    }
}

/// 現在地からの方位と距離を計算した印
struct ScopeTarget: Equatable, Identifiable {
    var mark: ScopeMark
    var bearing: Double
    var distance: Double
    /// 仰角(度)。印の上下の位置。高さが分からない、または高さを反映しないときは0(地平線の高さ)。
    var elevationAngle: Double = 0
    /// 高低差(m、印の高さ − 自分の高さ)。分からなければ nil。
    var heightDifference: Double? = nil
    var id: String { mark.id }

    /// 遠い順(描くときに、近い印が手前になるように)。
    /// observerAltitude: 自分の高さ。印と自分の両方の高さが分かり、usesHeight が true のときだけ、仰角に反映する。
    static func make(_ marks: [ScopeMark], latitude: Double, longitude: Double,
                     observerAltitude: Double? = nil, usesHeight: Bool = true) -> [ScopeTarget] {
        marks.map { mark in
            let distance = WaypointMath.distance(fromLatitude: latitude, longitude: longitude, toLatitude: mark.latitude, longitude: mark.longitude)
            var target = ScopeTarget(mark: mark,
                                     bearing: WaypointMath.bearing(fromLatitude: latitude, longitude: longitude,
                                                                   toLatitude: mark.latitude, longitude: mark.longitude),
                                     distance: distance)
            if let altitude = mark.altitude, let observerAltitude {
                target.heightDifference = altitude - observerAltitude
                if usesHeight {
                    target.elevationAngle = WaypointElevation.angle(targetAltitude: altitude, observerAltitude: observerAltitude, distance: distance)
                }
            }
            return target
        }
        .sorted { $0.distance > $1.distance }
    }
}

/// 見る位置と向き。カメラ表示(実際の端末の向き)と幽体離脱(地図で選んだ場所に立ったつもりの仮想の向き)で共通にする。
/// 重ねる情報の方角・距離・仰角・画面上の位置は、どちらもこの型だけを通して計算する。幽体離脱で確かめた見え方が、
/// カメラ表示でもそのまま正しくなるようにするため。
struct ScopeViewpoint: Equatable {
    var latitude: Double
    var longitude: Double
    /// 目の高さ(m、海面から)。分からなければ nil(印は地平線の高さに置く)
    var eyeAltitude: Double?
    var attitude: CameraAttitude
    /// 画面に写る範囲(画角の半分の正接。`WaypointProjection.tangents`)
    var horizontalTangent: Double
    var verticalTangent: Double

    var tangents: (horizontal: Double, vertical: Double) { (horizontalTangent, verticalTangent) }

    init(latitude: Double, longitude: Double, eyeAltitude: Double?, attitude: CameraAttitude,
         tangents: (horizontal: Double, vertical: Double)) {
        self.latitude = latitude
        self.longitude = longitude
        self.eyeAltitude = eyeAltitude
        self.attitude = attitude
        horizontalTangent = tangents.horizontal
        verticalTangent = tangents.vertical
    }

    /// 印の方角・距離・仰角(遠い順)
    func targets(_ marks: [ScopeMark], usesHeight: Bool = true) -> [ScopeTarget] {
        ScopeTarget.make(marks, latitude: latitude, longitude: longitude, observerAltitude: eyeAltitude, usesHeight: usesHeight)
    }

    /// 方角と仰角(度)の画面上の位置。後ろ側や画面の外なら nil
    func point(bearing: Double, elevation: Double, viewSize: CGSize) -> CGPoint? {
        WaypointProjection.point(bearing: bearing, elevation: elevation, attitude: attitude, tangents: tangents, viewSize: viewSize)
    }

    /// 地上の点(緯度経度と高さ)の画面上の位置。地球の丸みと屈折を含む(`WaypointElevation.angle`)
    func point(latitude: Double, longitude: Double, altitude: Double, viewSize: CGSize) -> CGPoint? {
        let distance = WaypointMath.distance(fromLatitude: self.latitude, longitude: self.longitude, toLatitude: latitude, longitude: longitude)
        let bearing = WaypointMath.bearing(fromLatitude: self.latitude, longitude: self.longitude, toLatitude: latitude, longitude: longitude)
        let angle = eyeAltitude.map { WaypointElevation.angle(targetAltitude: altitude, observerAltitude: $0, distance: distance) } ?? 0
        return point(bearing: bearing, elevation: angle, viewSize: viewSize)
    }
}

extension CameraAttitude {
    /// 方角 azimuth・仰角 elevation(度)を向き、左右に傾けない姿勢(幽体離脱の仮想のカメラと、テストに使う)
    static func looking(azimuth: Double, elevation: Double = 0) -> CameraAttitude {
        let a = azimuth * .pi / 180, e = elevation * .pi / 180
        let forward = Vector3(x: cos(e) * cos(a), y: -cos(e) * sin(a), z: sin(e))
        let right = Vector3(x: cos(a + .pi / 2), y: -sin(a + .pi / 2), z: 0)
        return CameraAttitude(right: right, up: Vector3.cross(right, forward), forward: forward)
    }
}
