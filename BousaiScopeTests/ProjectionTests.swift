import XCTest
@testable import BousaiScope

/// カメラ表示の投影: 方角どおりの場所に描かれるか、印と地上の点が同じ投影(ScopeViewpoint)で同じ場所に来るか
final class ProjectionTests: XCTestCase {
    private let size = CGSize(width: 375, height: 667)
    private let tangents = (horizontal: 0.6, vertical: 1.0)
    private let user = GeoPoint(35.68, 139.76)

    /// 背面カメラの方角・仰角の姿勢(傾きなし)。CMRotationMatrix と同じ形の値から作る
    private func camera(azimuth: Double, elevation: Double = 0) -> CameraAttitude {
        let a = azimuth * .pi / 180, e = elevation * .pi / 180
        let forward = Vector3(x: cos(e) * cos(a), y: -cos(e) * sin(a), z: sin(e))
        let right = Vector3(x: cos(a + .pi / 2), y: -sin(a + .pi / 2), z: 0)
        let up = Vector3.cross(right, forward)
        return CameraAttitude(m11: right.x, m12: right.y, m13: right.z, m21: up.x, m22: up.y, m23: up.z,
                              m31: -forward.x, m32: -forward.y, m33: -forward.z)
    }

    /// 現在地から、方角 bearing へ distance m の点
    private func point(bearing: Double, distance: Double) -> GeoPoint {
        let rad = bearing * .pi / 180
        return GeoMath.offset(user, east: distance * sin(rad), north: distance * cos(rad))
    }

    private func project(_ target: GeoPoint, attitude: CameraAttitude) -> CGPoint? {
        let bearing = WaypointMath.bearing(fromLatitude: user.latitude, longitude: user.longitude,
                                           toLatitude: target.latitude, longitude: target.longitude)
        return WaypointProjection.point(bearing: bearing, attitude: attitude, tangents: tangents, viewSize: size)
    }

    func testCardinalPointsAreAtCenterWhenFacingThem() {
        for (name, bearing) in [("北", 0.0), ("東", 90), ("南", 180), ("西", 270)] {
            let target = point(bearing: bearing, distance: 500)
            let projected = project(target, attitude: camera(azimuth: bearing))
            XCTAssertEqual(projected?.x ?? -1, size.width / 2, accuracy: 0.5, name)
            XCTAssertEqual(projected?.y ?? -1, size.height / 2, accuracy: 0.5, name)
            // 反対を向いたら描かない(カメラの後ろ)
            XCTAssertNil(project(target, attitude: camera(azimuth: bearing + 180)), name)
            // 90°横を向いたら、画面の外
            XCTAssertNil(project(target, attitude: camera(azimuth: bearing + 90)), name)
        }
    }

    func testNortheastIsRightOfNorthAndNorthwestIsLeft() {
        let north = camera(azimuth: 0)
        let northeast = project(point(bearing: 20, distance: 500), attitude: north)
        let northwest = project(point(bearing: 340, distance: 500), attitude: north)
        XCTAssertGreaterThan(northeast?.x ?? 0, size.width / 2 + 50)
        XCTAssertLessThan(northwest?.x ?? .infinity, size.width / 2 - 50)
        XCTAssertEqual(northeast?.y ?? 0, size.height / 2, accuracy: 0.5)
        // 45°の北東は、画角(左右に約31°)の外なので描かない
        XCTAssertNil(project(point(bearing: 45, distance: 500), attitude: north))
        // 北東を向けば中央
        XCTAssertEqual(project(point(bearing: 45, distance: 500), attitude: camera(azimuth: 45))?.x ?? -1, size.width / 2, accuracy: 0.5)
        // 上にあるものは中央より上
        let above = WaypointProjection.point(bearing: 0, elevation: 10, attitude: north, tangents: tangents, viewSize: size)
        XCTAssertLessThan(above?.y ?? .infinity, size.height / 2)
    }

    func testCompassRoseUsesSameProjection() {
        // 北を向くと「北」が中央、「東」は画面の外
        let north = ScopeCompassRose.marks(attitude: camera(azimuth: 0), tangents: tangents, size: size)
        XCTAssertEqual(north.map(\.name), ["北"])
        XCTAssertEqual(north.first?.point.x ?? -1, size.width / 2, accuracy: 1e-6)
        // 方角20°を向くと、「北」は左、「北東」は右
        let turned = ScopeCompassRose.marks(attitude: camera(azimuth: 20), tangents: tangents, size: size)
        let northMark = turned.first { $0.name == "北" }
        let northeastMark = turned.first { $0.name == "北東" }
        XCTAssertLessThan(northMark?.point.x ?? .infinity, size.width / 2)
        XCTAssertGreaterThan(northeastMark?.point.x ?? 0, size.width / 2)
        // 東を向くと「東」が中央
        let east = ScopeCompassRose.marks(attitude: camera(azimuth: 90), tangents: tangents, size: size)
        XCTAssertEqual(east.first { $0.name == "東" }?.point.x ?? -1, size.width / 2, accuracy: 1e-6)
        XCTAssertTrue(ScopeCompassRose.marks(attitude: camera(azimuth: 90), tangents: tangents, size: size).allSatisfy { $0.isCardinal == ($0.name.count == 1) })
        // 中央の文字
        XCTAssertEqual(ScopeCompassRose.centerText(azimuth: 123), "中央 123° → 南東(135°)の印が右に12°")
        XCTAssertEqual(ScopeCompassRose.centerText(azimuth: 350), "中央 350° → 北(0°)の印が右に10°")
        XCTAssertEqual(ScopeCompassRose.centerText(azimuth: 95), "中央 95° → 東(90°)の印が左に5°")
        XCTAssertEqual(ScopeCompassRose.centerText(azimuth: 270), "中央 270° → 西(270°)が中央")
        XCTAssertFalse(ScopeCompassRose.horizon(attitude: camera(azimuth: 0), tangents: tangents, size: size).isEmpty)
    }

    func testLocationErrorTurnsNearbyDirections() {
        // 位置の誤差 10m で 100m 先は約6°、誤差 100m で 50m 先は方向が決まらない
        XCTAssertEqual(ScopeLocationCheck.bearingUncertainty(accuracy: 10, distance: 100), asin(0.1) * 180 / .pi, accuracy: 1e-9)
        XCTAssertEqual(ScopeLocationCheck.bearingUncertainty(accuracy: 100, distance: 50), 180)
        XCTAssertNotNil(ScopeLocationCheck.warning(accuracy: 5, isReduced: true, nearest: 5_000))
        XCTAssertNotNil(ScopeLocationCheck.warning(accuracy: 30, isReduced: false, nearest: 50))
        XCTAssertNil(ScopeLocationCheck.warning(accuracy: 5, isReduced: false, nearest: 500))
        XCTAssertNil(ScopeLocationCheck.warning(accuracy: nil, isReduced: false, nearest: 50))
    }

    func testViewpointMatchesTargetsAndGroundPoints() throws {
        // 現在地から方角60°・300m、地面(標高0)の点を、方角50°を向いたカメラで見る。目の高さは1.5m
        let distance = 300.0
        let target = point(bearing: 60, distance: distance)
        let attitude = camera(azimuth: 50)
        let viewpoint = ScopeViewpoint(latitude: user.latitude, longitude: user.longitude, eyeAltitude: 1.5, attitude: attitude, tangents: tangents)

        // 地点の印(ScopeTarget の仰角)と、地上の点(緯度経度と高さ)が、同じ画面の位置に来る
        let mark = ScopeMark(id: "p", name: "地点", latitude: target.latitude, longitude: target.longitude, color: .red, altitude: 0)
        let made = try XCTUnwrap(viewpoint.targets([mark]).first)
        let byTarget = try XCTUnwrap(viewpoint.point(bearing: made.bearing, elevation: made.elevationAngle, viewSize: size))
        let byGround = try XCTUnwrap(viewpoint.point(latitude: target.latitude, longitude: target.longitude, altitude: 0, viewSize: size))
        XCTAssertEqual(byTarget.x, byGround.x, accuracy: 0.5)
        XCTAssertEqual(byTarget.y, byGround.y, accuracy: 0.5)
        // 方角は10°右なので、中央より右、地面なので中央より下
        XCTAssertGreaterThan(byTarget.x, size.width / 2 + 50)
        XCTAssertGreaterThan(byTarget.y, size.height / 2)

        // テスト用の姿勢と、幽体離脱で使う姿勢(CameraAttitude.looking)は同じ
        let looking = CameraAttitude.looking(azimuth: 50)
        XCTAssertEqual(looking.forward.x, attitude.forward.x, accuracy: 1e-9)
        XCTAssertEqual(looking.forward.y, attitude.forward.y, accuracy: 1e-9)
        XCTAssertEqual(looking.up.z, attitude.up.z, accuracy: 1e-9)
        XCTAssertEqual(looking.right.y, attitude.right.y, accuracy: 1e-9)

        // 目の高さが分からなければ、地平線の高さ(画面の中央の高さ)に置く
        var unknown = viewpoint
        unknown.eyeAltitude = nil
        let flat = try XCTUnwrap(unknown.point(latitude: target.latitude, longitude: target.longitude, altitude: 0, viewSize: size))
        XCTAssertEqual(flat.y, size.height / 2, accuracy: 0.5)
    }
}
