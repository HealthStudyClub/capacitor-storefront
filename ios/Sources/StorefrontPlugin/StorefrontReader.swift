import Foundation
import StoreKit

/// The values StoreKit reports for the current storefront.
public struct RawStorefront: Equatable, Sendable {
    /// ISO 3166-1 alpha-3 country code, e.g. `"DEU"`.
    public let countryCode: String
    /// App Store storefront identifier, e.g. `"143443"`.
    public let id: String

    public init(countryCode: String, id: String) {
        self.countryCode = countryCode
        self.id = id
    }
}

/// The storefront as it is handed to JavaScript.
public struct StorefrontInfo: Equatable, Sendable {
    public static let source = "appStore"

    /// ISO 3166-1 alpha-2 country code, upper case.
    public let countryCode: String
    /// ISO 3166-1 alpha-3 country code, upper case.
    public let countryCode3: String
    /// App Store storefront identifier.
    public let id: String

    public init(countryCode: String, countryCode3: String, id: String) {
        self.countryCode = countryCode
        self.countryCode3 = countryCode3
        self.id = id
    }

    /// Builds the info from the raw StoreKit values. Unknown alpha-3 codes are
    /// passed through as `countryCode` so the caller still gets a value.
    public init(raw: RawStorefront) {
        let alpha3 = raw.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.init(
            countryCode: CountryCodes.alpha2(fromAlpha3: alpha3) ?? alpha3,
            countryCode3: alpha3,
            id: raw.id
        )
    }

    /// The JSON payload resolved to the plugin call.
    public var dictionary: [String: Any] {
        [
            "countryCode": countryCode,
            "countryCode3": countryCode3,
            "id": id,
            "source": Self.source
        ]
    }
}

/// Errors a storefront lookup can fail with. `code` is what JavaScript sees
/// as `error.code`.
public enum StorefrontError: Error, Equatable {
    /// StoreKit did not report a storefront (`Storefront.current` was `nil`).
    case unavailable
    /// StoreKit did not answer within the timeout (milliseconds).
    case timeout(milliseconds: Double)

    public var code: String {
        switch self {
        case .unavailable: return "UNAVAILABLE"
        case .timeout: return "TIMEOUT"
        }
    }

    public var message: String {
        switch self {
        case .unavailable:
            return "StoreKit did not report a storefront (Storefront.current is nil)."
        case .timeout(let milliseconds):
            return "StoreKit did not report a storefront within \(Int(milliseconds)) ms."
        }
    }
}

/// Reads the current App Store storefront.
///
/// The StoreKit access is injectable so the mapping and timeout logic can be
/// tested without StoreKit, while `fetchFromStoreKit` is what the plugin uses
/// at runtime and what the simulator tests exercise through `SKTestSession`.
public final class StorefrontReader: Sendable {
    public typealias Fetch = @Sendable () async -> RawStorefront?

    /// Default timeout in milliseconds.
    public static let defaultTimeout: Double = 10_000

    private let fetch: Fetch

    public init(fetch: @escaping Fetch = StorefrontReader.fetchFromStoreKit) {
        self.fetch = fetch
    }

    /// Reads the storefront, failing with `StorefrontError.unavailable` when
    /// StoreKit reports none and with `StorefrontError.timeout` when it does
    /// not answer within `timeout` milliseconds.
    public func read(timeout: Double = StorefrontReader.defaultTimeout) async throws -> StorefrontInfo {
        let fetch = self.fetch
        let raw = try await Self.withTimeout(milliseconds: timeout) { await fetch() }
        guard let raw = raw else {
            throw StorefrontError.unavailable
        }
        return StorefrontInfo(raw: raw)
    }

    /// `StoreKit.Storefront.current`, reduced to the values the plugin needs.
    @Sendable
    public static func fetchFromStoreKit() async -> RawStorefront? {
        guard let storefront = await Storefront.current else {
            return nil
        }
        return RawStorefront(countryCode: storefront.countryCode, id: storefront.id)
    }

    private static func withTimeout<T: Sendable>(
        milliseconds: Double,
        _ operation: @escaping @Sendable () async -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                let nanoseconds = UInt64(max(0, milliseconds) * 1_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw StorefrontError.timeout(milliseconds: milliseconds)
            }
            guard let first = try await group.next() else {
                throw StorefrontError.unavailable
            }
            group.cancelAll()
            return first
        }
    }
}
