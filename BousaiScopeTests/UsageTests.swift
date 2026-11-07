import XCTest
@testable import BousaiScope

/// 通信量の分類と、重いデータを保存してよい回線の判定
final class UsageTests: XCTestCase {
    func testUsageCategoryFromURL() {
        func category(_ text: String) -> UsageCategory { UsageCategory.from(url: URL(string: text)) }
        XCTAssertEqual(category("https://cyberjapandata2.gsi.go.jp/general/dem/scripts/getelevation.php?lon=139&lat=35&outtype=JSON"), .elevation)
        XCTAssertEqual(category("https://cyberjapandata.gsi.go.jp/xyz/dem_png/12/3637/1612.png"), .terrain)
        XCTAssertEqual(category("https://cyberjapandata.gsi.go.jp/xyz/seamlessphoto/17/116418/51611.jpg"), .terrain)
        XCTAssertEqual(category("https://cyberjapandata.gsi.go.jp/xyz/skhb01/10/909/403.geojson"), .shelters)
        XCTAssertEqual(category("https://disaportaldata.gsi.go.jp/raster/01_flood_l2_shinsuishin_data/14/14552/6450.png"), .hazard)
        XCTAssertEqual(category("https://www.jma.go.jp/bosai/quake/data/list.json"), .quake)
        XCTAssertEqual(category("https://api.p2pquake.net/v2/history?codes=551&limit=1"), .quake)
        XCTAssertEqual(category("https://example.com/"), .other)
    }

    func testHeavyDataOnlyOnUnmeteredNetworks() {
        XCTAssertTrue(NetworkStatus(isOnline: true, isExpensive: false, isConstrained: false, isWiFi: true).canDownloadHeavyData)
        XCTAssertFalse(NetworkStatus(isOnline: true, isExpensive: true, isConstrained: false, isWiFi: false).canDownloadHeavyData)
        XCTAssertFalse(NetworkStatus(isOnline: true, isExpensive: false, isConstrained: true, isWiFi: true).canDownloadHeavyData)
        XCTAssertFalse(NetworkStatus.unknown.canDownloadHeavyData)
    }

    func testElevationRefreshIsAllowedOnCellularButNotInLowDataMode() {
        let policy = RefreshPolicy(wifiOnly: false)
        let cellular = NetworkStatus(isOnline: true, isExpensive: true, isConstrained: false, isWiFi: false)
        XCTAssertEqual(policy.autoDecision(kind: .elevation, fetchedAt: nil, now: Date(), network: cellular), .refresh)
        let constrained = NetworkStatus(isOnline: true, isExpensive: true, isConstrained: true, isWiFi: false)
        XCTAssertEqual(policy.autoDecision(kind: .elevation, fetchedAt: nil, now: Date(), network: constrained), .blockedByConstrained)
        XCTAssertEqual(RefreshPolicy(wifiOnly: true).autoDecision(kind: .elevation, fetchedAt: nil, now: Date(), network: cellular), .blockedByWiFiOnly)
    }
}
