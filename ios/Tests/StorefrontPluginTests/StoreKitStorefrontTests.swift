import XCTest
import StoreKit
import StoreKitTest
@testable import StorefrontPlugin

/// Simulator tests that go through the real StoreKit API.
///
/// `testReadsTheStorefrontTheSimulatorReports` works on every simulator. The
/// remaining tests use StoreKit Testing (`SKTestSession`) to choose the
/// storefront the simulator reports, which makes `Storefront.current`
/// deterministic. Since the iOS 26.3 simulator runtime, `SKTestSession` cannot
/// apply its configuration when tests are started with `xcodebuild` (Apple bug
/// FB22237318); those tests then skip with a diagnostic instead of failing.
/// `scripts/test-ios.sh` prefers an unaffected runtime (iOS 26.2 or older).
final class StoreKitStorefrontTests: XCTestCase {
    private static let overrideTimeout: TimeInterval = 5

    private var session: SKTestSession?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Storefront", withExtension: "storekit"),
            "Storefront.storekit is missing from the test bundle"
        )
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        self.session = session
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session = nil
        try super.tearDownWithError()
    }

    /// Runs on every simulator: whatever storefront StoreKit reports, the
    /// plugin has to read it and map it consistently.
    func testReadsTheStorefrontTheSimulatorReports() async throws {
        let info = try await StorefrontReader().read(timeout: 5_000)
        let current = await Storefront.current
        let expected = try XCTUnwrap(current, "the simulator reports no storefront at all")

        XCTAssertEqual(info.countryCode3, expected.countryCode)
        XCTAssertEqual(info.id, expected.id)
        XCTAssertTrue(info.countryCode3.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil, info.countryCode3)
        XCTAssertEqual(info.countryCode, CountryCodes.alpha2(fromAlpha3: info.countryCode3), "storefront \(info.countryCode3) is not in the country table")
        XCTAssertEqual(info.dictionary["source"] as? String, "appStore")
    }

    func testStorefrontCurrentFollowsTheTestSession() async throws {
        try await select(storefront: "GBR")

        let storefront = await Storefront.current

        XCTAssertEqual(storefront?.countryCode, "GBR")
    }

    func testReadsGermanStorefront() async throws {
        try await select(storefront: "DEU")

        let info = try await StorefrontReader().read()

        XCTAssertEqual(info.countryCode3, "DEU")
        XCTAssertEqual(info.countryCode, "DE")
        XCTAssertEqual(info.dictionary["source"] as? String, "appStore")
    }

    func testReadsUSStorefront() async throws {
        try await select(storefront: "USA")

        let info = try await StorefrontReader().read()

        XCTAssertEqual(info.countryCode3, "USA")
        XCTAssertEqual(info.countryCode, "US")
    }

    func testPluginResolvesStorefrontThroughStoreKit() async throws {
        try await select(storefront: "CHE")

        let info = try await StorefrontReader(fetch: StorefrontReader.fetchFromStoreKit).read(timeout: 5_000)

        XCTAssertEqual(info.countryCode, "CH")
        XCTAssertEqual(info.countryCode3, "CHE")
        XCTAssertNotNil(info.dictionary["id"] as? String)
    }

    /// Switches the test session's storefront and waits until StoreKit reports
    /// it. Skips the test when the simulator ignores the override (FB22237318).
    private func select(storefront code: String) async throws {
        let session = try XCTUnwrap(session, "StoreKit test session was not set up")
        session.storefront = code
        let deadline = Date().addingTimeInterval(Self.overrideTimeout)
        while Date() < deadline {
            if await Storefront.current?.countryCode == code {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let actual = await Storefront.current?.countryCode ?? "nil"
        throw XCTSkip(
            "StoreKit Testing could not switch the storefront to \(code) (simulator still reports \(actual)). "
                + "This is Apple bug FB22237318 on iOS 26.3+ simulator runtimes when tests run via xcodebuild; "
                + "run on an iOS 26.2 or older simulator (see scripts/test-ios.sh) for the deterministic storefront tests."
        )
    }
}
