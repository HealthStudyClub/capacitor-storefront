import XCTest
@testable import StorefrontPlugin

final class StorefrontReaderTests: XCTestCase {
    private static let marketplace = AppDistribution.marketplace("com.example.marketplace")

    private func reader(
        distribution: AppDistribution = .appStore,
        fetch: @escaping StorefrontReader.Fetch
    ) -> StorefrontReader {
        StorefrontReader(fetch: fetch, fetchDistribution: { distribution })
    }

    func testMapsRawStorefrontToInfo() async throws {
        let reader = reader { RawStorefront(countryCode: "DEU", id: "143443") }

        let info = try await reader.read()

        XCTAssertEqual(info, StorefrontInfo(countryCode: "DE", countryCode3: "DEU", id: "143443", distribution: .appStore))
    }

    func testCarriesTheDistribution() async throws {
        let reader = reader(distribution: Self.marketplace) { RawStorefront(countryCode: "DEU", id: "143443") }

        let info = try await reader.read()

        XCTAssertEqual(info.distribution, Self.marketplace)
        XCTAssertEqual(info.dictionary["source"] as? String, "marketplace")
        XCTAssertEqual(info.dictionary["installer"] as? String, "com.example.marketplace")
    }

    func testNormalisesCountryCodeCase() async throws {
        let reader = reader { RawStorefront(countryCode: "usa", id: "143441") }

        let info = try await reader.read()

        XCTAssertEqual(info.countryCode, "US")
        XCTAssertEqual(info.countryCode3, "USA")
    }

    func testUnknownAlpha3CodeIsPassedThrough() async throws {
        let reader = reader { RawStorefront(countryCode: "XYZ", id: "1") }

        let info = try await reader.read()

        XCTAssertEqual(info.countryCode, "XYZ")
        XCTAssertEqual(info.countryCode3, "XYZ")
    }

    func testMissingStorefrontIsUnavailableAndStillReportsTheDistribution() async {
        let reader = reader(distribution: Self.marketplace) { nil }

        do {
            _ = try await reader.read()
            XCTFail("expected an error")
        } catch let error as StorefrontError {
            XCTAssertEqual(error, .unavailable(distribution: Self.marketplace))
            XCTAssertEqual(error.code, "UNAVAILABLE")
            XCTAssertEqual(error.data?["source"] as? String, "marketplace")
            XCTAssertEqual(error.data?["installer"] as? String, "com.example.marketplace")
            XCTAssertEqual(error.data?.count, 2)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testMissingStorefrontFromTheAppStoreHasSourceOnlyInData() async {
        let reader = reader { nil }

        do {
            _ = try await reader.read()
            XCTFail("expected an error")
        } catch let error as StorefrontError {
            XCTAssertEqual(error.data?["source"] as? String, "appStore")
            XCTAssertEqual(error.data?.count, 1)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testSlowStoreKitTimesOut() async {
        let reader = reader {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return RawStorefront(countryCode: "DEU", id: "143443")
        }

        await assertTimesOut(reader)
    }

    func testHangingStoreKitStillTimesOut() async {
        // Never resumes and ignores cancellation, like a stuck system call.
        let reader = reader { await withUnsafeContinuation { (_: UnsafeContinuation<RawStorefront?, Never>) in } }

        await assertTimesOut(reader)
    }

    func testSlowMarketplaceKitFallsBackToOtherAndKeepsTheStorefront() async throws {
        let reader = StorefrontReader(
            fetch: { RawStorefront(countryCode: "DEU", id: "143443") },
            fetchDistribution: {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return .appStore
            }
        )
        let start = Date()

        let info = try await reader.read(timeout: 200)

        XCTAssertEqual(info.countryCode, "DE")
        XCTAssertEqual(info.distribution, .other)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3, "the distribution lookup must not exceed the timeout")
    }

    func testHangingMarketplaceKitFallsBackToOther() async throws {
        let reader = StorefrontReader(
            fetch: { RawStorefront(countryCode: "DEU", id: "143443") },
            fetchDistribution: { await withUnsafeContinuation { (_: UnsafeContinuation<AppDistribution, Never>) in } }
        )

        let info = try await reader.read(timeout: 200)

        XCTAssertEqual(info.distribution, .other)
        XCTAssertEqual(info.dictionary["source"] as? String, "other")
    }

    func testMissingStorefrontWithSlowMarketplaceKitReportsOtherInData() async {
        let reader = StorefrontReader(
            fetch: { nil },
            fetchDistribution: {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return .appStore
            }
        )

        do {
            _ = try await reader.read(timeout: 200)
            XCTFail("expected an error")
        } catch let error as StorefrontError {
            XCTAssertEqual(error, .unavailable(distribution: .other))
            XCTAssertEqual(error.data?["source"] as? String, "other")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    private func assertTimesOut(_ reader: StorefrontReader, file: StaticString = #filePath, line: UInt = #line) async {
        let start = Date()
        do {
            _ = try await reader.read(timeout: 100)
            XCTFail("expected a timeout", file: file, line: line)
        } catch let error as StorefrontError {
            XCTAssertEqual(error, .timeout(milliseconds: 100), file: file, line: line)
            XCTAssertEqual(error.code, "TIMEOUT", file: file, line: line)
            XCTAssertNil(error.data, file: file, line: line)
            XCTAssertLessThan(Date().timeIntervalSince(start), 3, "the timeout must not wait for the slow fetch", file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }

    func testDictionaryPayloadForAppStoreInstall() {
        let info = StorefrontInfo(countryCode: "DE", countryCode3: "DEU", id: "143443", distribution: .appStore)

        let payload = info.dictionary

        XCTAssertEqual(payload["countryCode"] as? String, "DE")
        XCTAssertEqual(payload["countryCode3"] as? String, "DEU")
        XCTAssertEqual(payload["id"] as? String, "143443")
        XCTAssertEqual(payload["source"] as? String, "appStore")
        XCTAssertNil(payload["installer"])
        XCTAssertEqual(payload.count, 4)
    }

    func testDictionaryPayloadForMarketplaceInstall() {
        let info = StorefrontInfo(countryCode: "DE", countryCode3: "DEU", id: "143443", distribution: Self.marketplace)

        let payload = info.dictionary

        XCTAssertEqual(payload["source"] as? String, "marketplace")
        XCTAssertEqual(payload["installer"] as? String, "com.example.marketplace")
        XCTAssertEqual(payload.count, 5)
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
