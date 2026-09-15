import XCTest
import StoreKit
import StoreKitTest
@testable import StorefrontPlugin

/// Simulator tests that go through the real StoreKit API.
///
/// StoreKit Testing (`SKTestSession`) lets the test choose the storefront the
/// simulator reports, so `Storefront.current` becomes deterministic.
final class StoreKitStorefrontTests: XCTestCase {
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

    /// Switches the test session's storefront and waits until StoreKit reports it.
    private func select(storefront code: String, timeout: TimeInterval = 10) async throws {
        let session = try XCTUnwrap(session, "StoreKit test session was not set up")
        session.storefront = code
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await Storefront.current?.countryCode == code {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let actual = await Storefront.current?.countryCode ?? "nil"
        XCTFail("StoreKit still reports storefront \(actual) instead of \(code) after \(Int(timeout)) s")
    }
}
