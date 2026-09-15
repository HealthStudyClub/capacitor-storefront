import XCTest
@testable import StorefrontPlugin

final class StorefrontReaderTests: XCTestCase {
    func testMapsRawStorefrontToInfo() async throws {
        let reader = StorefrontReader { RawStorefront(countryCode: "DEU", id: "143443") }

        let info = try await reader.read()

        XCTAssertEqual(info, StorefrontInfo(countryCode: "DE", countryCode3: "DEU", id: "143443"))
    }

    func testNormalisesCountryCodeCase() async throws {
        let reader = StorefrontReader { RawStorefront(countryCode: "usa", id: "143441") }

        let info = try await reader.read()

        XCTAssertEqual(info.countryCode, "US")
        XCTAssertEqual(info.countryCode3, "USA")
    }

    func testUnknownAlpha3CodeIsPassedThrough() async throws {
        let reader = StorefrontReader { RawStorefront(countryCode: "XYZ", id: "1") }

        let info = try await reader.read()

        XCTAssertEqual(info.countryCode, "XYZ")
        XCTAssertEqual(info.countryCode3, "XYZ")
    }

    func testMissingStorefrontIsUnavailable() async {
        let reader = StorefrontReader { nil }

        do {
            _ = try await reader.read()
            XCTFail("expected an error")
        } catch let error as StorefrontError {
            XCTAssertEqual(error, .unavailable)
            XCTAssertEqual(error.code, "UNAVAILABLE")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testSlowStoreKitTimesOut() async {
        let reader = StorefrontReader {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return RawStorefront(countryCode: "DEU", id: "143443")
        }

        let start = Date()
        do {
            _ = try await reader.read(timeout: 100)
            XCTFail("expected a timeout")
        } catch let error as StorefrontError {
            XCTAssertEqual(error, .timeout(milliseconds: 100))
            XCTAssertEqual(error.code, "TIMEOUT")
            XCTAssertLessThan(Date().timeIntervalSince(start), 3, "the timeout must not wait for the slow fetch")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testDictionaryPayload() {
        let info = StorefrontInfo(countryCode: "DE", countryCode3: "DEU", id: "143443")

        let payload = info.dictionary

        XCTAssertEqual(payload["countryCode"] as? String, "DE")
        XCTAssertEqual(payload["countryCode3"] as? String, "DEU")
        XCTAssertEqual(payload["id"] as? String, "143443")
        XCTAssertEqual(payload["source"] as? String, "appStore")
        XCTAssertEqual(payload.count, 4)
    }

    func testPluginTimeoutOptionFallsBackToDefault() {
        XCTAssertEqual(StorefrontPlugin.timeout(from: nil), StorefrontReader.defaultTimeout)
        XCTAssertEqual(StorefrontPlugin.timeout(from: 0), StorefrontReader.defaultTimeout)
        XCTAssertEqual(StorefrontPlugin.timeout(from: -5), StorefrontReader.defaultTimeout)
        XCTAssertEqual(StorefrontPlugin.timeout(from: .nan), StorefrontReader.defaultTimeout)
        XCTAssertEqual(StorefrontPlugin.timeout(from: .infinity), StorefrontReader.defaultTimeout)
        XCTAssertEqual(StorefrontPlugin.timeout(from: 2_500), 2_500)
    }
}
