import XCTest
@testable import StorefrontPlugin

final class CountryCodesTests: XCTestCase {
    func testMapsCommonStorefronts() {
        XCTAssertEqual(CountryCodes.alpha2(fromAlpha3: "USA"), "US")
        XCTAssertEqual(CountryCodes.alpha2(fromAlpha3: "DEU"), "DE")
        XCTAssertEqual(CountryCodes.alpha2(fromAlpha3: "GBR"), "GB")
        XCTAssertEqual(CountryCodes.alpha2(fromAlpha3: "CHE"), "CH")
        XCTAssertEqual(CountryCodes.alpha2(fromAlpha3: "AUT"), "AT")
        XCTAssertEqual(CountryCodes.alpha2(fromAlpha3: "JPN"), "JP")
    }

    func testLookupIsCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(CountryCodes.alpha2(fromAlpha3: "deu"), "DE")
        XCTAssertEqual(CountryCodes.alpha2(fromAlpha3: " usa\n"), "US")
    }

    func testUnknownCodeReturnsNil() {
        XCTAssertNil(CountryCodes.alpha2(fromAlpha3: "XXX"))
        XCTAssertNil(CountryCodes.alpha2(fromAlpha3: ""))
        XCTAssertNil(CountryCodes.alpha2(fromAlpha3: "DE"))
    }

    func testTableCoversAllIsoCountriesAndIsUnambiguous() {
        XCTAssertEqual(CountryCodes.count, 249)
        let alpha2Codes = Set(CountryCodes.alpha3ToAlpha2.values)
        XCTAssertEqual(alpha2Codes.count, CountryCodes.count, "every alpha-3 code must map to a distinct alpha-2 code")
        for (alpha3, alpha2) in CountryCodes.alpha3ToAlpha2 {
            XCTAssertEqual(alpha3.count, 3, alpha3)
            XCTAssertEqual(alpha2.count, 2, alpha2)
            XCTAssertEqual(alpha3, alpha3.uppercased())
            XCTAssertEqual(alpha2, alpha2.uppercased())
        }
    }
}
