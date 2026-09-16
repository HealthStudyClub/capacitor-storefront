import XCTest
#if canImport(MarketplaceKit)
import MarketplaceKit
#endif
@testable import StorefrontPlugin

final class AppDistributionTests: XCTestCase {
    func testSourcesWithoutInstaller() {
        XCTAssertEqual(AppDistribution.appStore.dictionary as? [String: String], ["source": "appStore"])
        XCTAssertEqual(AppDistribution.testFlight.dictionary as? [String: String], ["source": "testFlight"])
        XCTAssertEqual(AppDistribution.web.dictionary as? [String: String], ["source": "web"])
        XCTAssertEqual(AppDistribution.other.dictionary as? [String: String], ["source": "other"])
    }

    func testMarketplaceCarriesTheInstaller() {
        let distribution = AppDistribution.marketplace("com.altstore.pal")

        XCTAssertEqual(distribution.source, "marketplace")
        XCTAssertEqual(distribution.installer, "com.altstore.pal")
        XCTAssertEqual(distribution.dictionary as? [String: String], ["source": "marketplace", "installer": "com.altstore.pal"])
    }

    #if canImport(MarketplaceKit)
    func testMapsEveryMarketplaceKitDistributor() throws {
        guard #available(iOS 17.5, *) else {
            throw XCTSkip("MarketplaceKit.AppDistributor needs iOS 17.5 for all cases")
        }
        XCTAssertEqual(AppDistribution(distributor: MarketplaceKit.AppDistributor.appStore), .appStore)
        XCTAssertEqual(AppDistribution(distributor: MarketplaceKit.AppDistributor.testFlight), .testFlight)
        XCTAssertEqual(
            AppDistribution(distributor: MarketplaceKit.AppDistributor.marketplace("com.example.market")),
            .marketplace("com.example.market")
        )
        XCTAssertEqual(AppDistribution(distributor: MarketplaceKit.AppDistributor.web), .web)
        XCTAssertEqual(AppDistribution(distributor: MarketplaceKit.AppDistributor.other), .other)
    }
    #endif

    /// Before iOS 17.4 there is no MarketplaceKit and no alternative
    /// distribution, so the plugin has to report `appStore` right away.
    func testBeforeIOS174ReportsAppStoreWithoutMarketplaceKit() async throws {
        if #available(iOS 17.4, *) {
            throw XCTSkip("MarketplaceKit is available on this runtime")
        }
        let start = Date()

        let distribution = await AppDistribution.fetchFromMarketplaceKit()

        XCTAssertEqual(distribution, .appStore)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1, "no lookup must happen before iOS 17.4")
    }

    /// The real MarketplaceKit path, bounded by the reader's timeout: in a
    /// hostless test bundle on the simulator `AppDistributor.current` never
    /// answers, so the reader has to fall back to `other` in time instead of
    /// hanging. Wherever it does answer, the source has to be a documented one.
    func testMarketplaceKitPathSettlesWithADocumentedSource() async throws {
        let reader = StorefrontReader(
            fetch: { RawStorefront(countryCode: "DEU", id: "143443") },
            fetchDistribution: AppDistribution.fetchFromMarketplaceKit
        )
        let start = Date()

        let info = try await reader.read(timeout: 2_000)

        print("MarketplaceKit path reports distribution \(info.distribution) on this simulator")
        XCTAssertLessThan(Date().timeIntervalSince(start), 4, "the distribution lookup must respect the timeout")
        XCTAssertTrue(["appStore", "testFlight", "marketplace", "web", "other"].contains(info.distribution.source), info.distribution.source)
        if info.distribution.source == "marketplace" {
            XCTAssertNotNil(info.distribution.installer)
        } else {
            XCTAssertNil(info.distribution.installer)
        }
    }
}
