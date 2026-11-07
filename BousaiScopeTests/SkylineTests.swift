import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import BousaiScope

/// 決まった地形(緯度経度から標高を返す)
private struct FakeTerrain: TerrainSampling {
    let height: (Double, Double) -> TerrainGrid.Sample

    func sample(latitude: Double, longitude: Double, distance: Double) -> TerrainGrid.Sample {
        height(latitude, longitude)
    }
}

/// 景色の稜線と地形(スマートダッシュボードのテストから、写した計算の分だけを持ってきた)
final class SkylineTests: XCTestCase {
    private let lat = 35.0
    private let lon = 139.0

    private func distance(_ a: Double, _ b: Double) -> Double {
        WaypointMath.distance(fromLatitude: lat, longitude: lon, toLatitude: a, longitude: b)
    }

    /// 地球の丸みを補正した、平らな地面(海面)の見かけの地平線: 仰角 ≒ −2√(目の高さ ÷ 2R')、距離 ≒ √(2R'×目の高さ)
    private func flatHorizon(eye: Double) -> (angle: Double, distance: Double) {
        let effective = WaypointElevation.earthRadius / (1 - WaypointElevation.refraction)
        let distance = sqrt(2 * effective * eye)
        return (WaypointElevation.angle(targetAltitude: 0, observerAltitude: eye, distance: distance), distance)
    }

    func testFlatLandHorizon() {
        let terrain = FakeTerrain { _, _ in .elevation(0) }
        let (skyline, _) = SkylineCalculator.compute(latitude: lat, longitude: lon, eye: 10, radius: 30_000, terrain: terrain)
        XCTAssertEqual(skyline.rayCount, 720)
        XCTAssertEqual(skyline.coverage, 1)
        let expected = flatHorizon(eye: 10)
        for bearing in [0.0, 90, 181.5, 359.5] {
            let horizon = skyline.ray(atBearing: bearing).horizon
            XCTAssertEqual(Double(horizon?.angle ?? 0), expected.angle, accuracy: 0.005, "\(bearing)")
            XCTAssertEqual(Double(horizon?.distance ?? 0), expected.distance, accuracy: expected.distance * 0.1)
        }
        XCTAssertLessThan(expected.angle, 0)
    }

    func testNearbyHillBlocksTheView() {
        // 北へ1kmの所に、半径300m・高さ100mの丘
        let hillLat = lat + 1000 / 111_320.0
        let terrain = FakeTerrain { a, b in
            WaypointMath.distance(fromLatitude: hillLat, longitude: self.lon, toLatitude: a, longitude: b) < 300 ? .elevation(100) : .elevation(0)
        }
        let (skyline, _) = SkylineCalculator.compute(latitude: lat, longitude: lon, eye: 1.5, radius: 20_000, terrain: terrain)
        let north = skyline.horizonAngle(atBearing: 0) ?? -90
        XCTAssertGreaterThan(north, 5)
        XCTAssertLessThan(north, 10)
        XCTAssertEqual(Double(skyline.ray(atBearing: 0).horizon?.distance ?? 0), 700, accuracy: 60)
        XCTAssertEqual(skyline.horizonAngle(atBearing: 180) ?? 0, flatHorizon(eye: 1.5).angle, accuracy: 0.005)
        // 丘の向こう5kmの低い所は隠れ、高い所は見える。丘より手前は見える
        XCTAssertEqual(skyline.visibility(bearing: 0, distance: 5000, angle: 0), .hidden)
        XCTAssertEqual(skyline.visibility(bearing: 0, distance: 5000, angle: 12), .visible)
        XCTAssertEqual(skyline.visibility(bearing: 0, distance: 500, angle: 0), .visible)
        XCTAssertEqual(skyline.visibility(bearing: 180, distance: 5000, angle: 0), .visible)
    }

    func testFarMountainWithCurvature() throws {
        // 東へ50kmに、高さ2000m(すそ野の半径10km)の円すいの山
        let peak = (latitude: lat, longitude: lon + 50_000 / (111_320 * cos(lat * .pi / 180)))
        let terrain = FakeTerrain { a, b in
            let d = WaypointMath.distance(fromLatitude: peak.latitude, longitude: peak.longitude, toLatitude: a, longitude: b)
            return .elevation(max(0, 2000 - d * 0.2))
        }
        let (skyline, _) = SkylineCalculator.compute(latitude: lat, longitude: lon, eye: 1.5, radius: 100_000, terrain: terrain)
        let expected = WaypointElevation.angle(targetAltitude: 2000, observerAltitude: 1.5, distance: 50_000)
        XCTAssertEqual(expected, 2.1, accuracy: 0.05)
        let east = try XCTUnwrap(skyline.ray(atBearing: 90).horizon)
        XCTAssertEqual(Double(east.angle), expected, accuracy: 0.15)
        XCTAssertEqual(Double(east.distance), 50_000, accuracy: 1500)

        // 稜線の線: 地平線の線ができる。濃さは遠いほど薄い
        let lines = RidgeExtractor.lines(from: skyline)
        XCTAssertTrue(lines.contains { $0.isHorizon && $0.points.count >= 3 })
        XCTAssertGreaterThan(RidgeLine.opacity(distance: 2000), RidgeLine.opacity(distance: 50_000))
    }

    func testMissingTerrainIsUnknown() {
        // 10kmより先はデータなし
        let terrain = FakeTerrain { a, b in
            WaypointMath.distance(fromLatitude: self.lat, longitude: self.lon, toLatitude: a, longitude: b) > 10_000 ? .missing : .elevation(0)
        }
        let (skyline, _) = SkylineCalculator.compute(latitude: lat, longitude: lon, eye: 300, radius: 50_000, terrain: terrain)
        XCTAssertEqual(skyline.coverage, 0)
        XCTAssertEqual(skyline.visibility(bearing: 10, distance: 30_000, angle: -5), .unknown)
    }

    func testElevationTileValues() throws {
        XCTAssertEqual(GSIElevationTile.elevation(r: 0, g: 0, b: 0), 0)
        XCTAssertEqual(GSIElevationTile.elevation(r: 0, g: 1, b: 0), 2.56, accuracy: 0.0001)
        XCTAssertTrue(GSIElevationTile.elevation(r: 128, g: 0, b: 0).isNaN)
        XCTAssertEqual(GSIElevationTile.elevation(r: 255, g: 255, b: 255), -0.01, accuracy: 0.0001)

        // 1234.56m の PNG を作って読む(色の変換をしないこと)
        let value = 123_456
        let size = TerrainGrid.tileSize
        let context = try XCTUnwrap(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let pixels = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: size * size * 4)
        for i in 0..<(size * size) {
            pixels[i * 4] = UInt8((value >> 16) & 0xFF)
            pixels[i * 4 + 1] = UInt8((value >> 8) & 0xFF)
            pixels[i * 4 + 2] = UInt8(value & 0xFF)
            pixels[i * 4 + 3] = 255
        }
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let values = try XCTUnwrap(GSIElevationTile.decode(data as Data))
        XCTAssertEqual(values.count, size * size)
        XCTAssertEqual(Double(values[0]), 1234.56, accuracy: 0.01)
        XCTAssertEqual(Double(values[size * size - 1]), 1234.56, accuracy: 0.01)
    }

    func testTerrainGridZoomsAndNeededTiles() {
        XCTAssertEqual(TerrainGrid.zoom(forDistance: 1000), 12)
        XCTAssertEqual(TerrainGrid.zoom(forDistance: 20_000), 10)
        XCTAssertEqual(TerrainGrid.zoom(forDistance: 80_000), 9)
        let near = TerrainGrid.neededTiles(latitude: 35.68, longitude: 139.77, radius: 30_000)
        XCTAssertTrue(near.contains { $0.z == 12 })
        XCTAssertTrue(near.contains { $0.z == 10 })
        XCTAssertFalse(near.contains { $0.z == 9 })
        let far = TerrainGrid.neededTiles(latitude: 35.68, longitude: 139.77, radius: 100_000)
        XCTAssertTrue(far.contains { $0.z == 9 })
        XCTAssertLessThanOrEqual(far.count, 40)
        // タイルの番号と緯度経度の行き来
        let (key, fx, fy) = TileKey.locate(latitude: 35.3606, longitude: 138.7274, zoom: 12)
        let back = TileKey.coordinate(x: Double(key.x) + fx, y: Double(key.y) + fy, zoom: 12)
        XCTAssertEqual(back.latitude, 35.3606, accuracy: 1e-6)
        XCTAssertEqual(back.longitude, 138.7274, accuracy: 1e-6)
        // 海の上(データなし)は海、タイルがなければ分からない
        var tile = [Float](repeating: 10, count: TerrainGrid.tileSize * TerrainGrid.tileSize)
        tile[0] = .nan
        let corner = TileKey.coordinate(x: Double(key.x) + 0.001, y: Double(key.y) + 0.001, zoom: 12)
        let grid = TerrainGrid(tiles: [key: tile])
        XCTAssertEqual(grid.sample(latitude: corner.latitude, longitude: corner.longitude, distance: 100), .sea)
        XCTAssertEqual(grid.sample(latitude: 35.3606, longitude: 138.7274, distance: 100), .elevation(10))
        XCTAssertEqual(grid.sample(latitude: 35.3606, longitude: 138.7274, distance: 50_000), .missing)
    }
}
