import Foundation
import os
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
    /// ISO 3166-1 alpha-2 country code, upper case.
    public let countryCode: String
    /// ISO 3166-1 alpha-3 country code, upper case.
    public let countryCode3: String
    /// App Store storefront identifier.
    public let id: String
    /// The channel the app was distributed through.
    public let distribution: AppDistribution

    public init(countryCode: String, countryCode3: String, id: String, distribution: AppDistribution = .appStore) {
        self.countryCode = countryCode
        self.countryCode3 = countryCode3
        self.id = id
        self.distribution = distribution
    }

    /// Builds the info from the raw StoreKit values. Unknown alpha-3 codes are
    /// passed through as `countryCode` so the caller still gets a value.
    public init(raw: RawStorefront, distribution: AppDistribution) {
        let alpha3 = raw.countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.init(
            countryCode: CountryCodes.alpha2(fromAlpha3: alpha3) ?? alpha3,
            countryCode3: alpha3,
            id: raw.id,
            distribution: distribution
        )
    }

    /// The JSON payload resolved to the plugin call.
    public var dictionary: [String: Any] {
        var dictionary: [String: Any] = [
            "countryCode": countryCode,
            "countryCode3": countryCode3,
            "id": id
        ]
        dictionary.merge(distribution.dictionary) { _, new in new }
        return dictionary
    }
}

/// Errors a storefront lookup can fail with. `code` is what JavaScript sees
/// as `error.code`, `data` as `error.data`.
public enum StorefrontError: Error, Equatable {
    /// StoreKit did not report a storefront (`Storefront.current` was `nil`).
    /// The distribution is still reported so the caller can tell where the
    /// app came from.
    case unavailable(distribution: AppDistribution?)
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

    /// Extra data for the rejected call, or `nil` when there is none.
    public var data: [String: Any]? {
        switch self {
        case .unavailable(let distribution): return distribution?.dictionary
        case .timeout: return nil
        }
    }
}

/// Reads the current App Store storefront and the app's distribution channel.
///
/// Both lookups are injectable so the mapping and timeout logic can be tested
/// without StoreKit and MarketplaceKit, while the defaults are what the plugin
/// uses at runtime and what the simulator tests exercise.
public final class StorefrontReader: Sendable {
    public typealias Fetch = @Sendable () async -> RawStorefront?
    public typealias FetchDistribution = @Sendable () async -> AppDistribution

    /// Default timeout in milliseconds.
    public static let defaultTimeout: Double = 10_000

    private static let logger = Logger(subsystem: "health.hsc.storefront", category: "Storefront")

    private let fetch: Fetch
    private let fetchDistribution: FetchDistribution

    public init(
        fetch: @escaping Fetch = StorefrontReader.fetchFromStoreKit,
        fetchDistribution: @escaping FetchDistribution = AppDistribution.fetchFromMarketplaceKit
    ) {
        self.fetch = fetch
        self.fetchDistribution = fetchDistribution
    }

    /// Reads the storefront and the distribution concurrently.
    ///
    /// Fails with `StorefrontError.timeout` when StoreKit does not answer within
    /// `timeout` milliseconds and with `StorefrontError.unavailable` when it
    /// reports no storefront. The distribution lookup shares the same budget:
    /// when MarketplaceKit has not answered by the time the storefront is known
    /// and the timeout expires, the distribution is reported as `other` and the
    /// storefront is still returned.
    public func read(timeout: Double = StorefrontReader.defaultTimeout) async throws -> StorefrontInfo {
        let fetch = self.fetch
        let fetchDistribution = self.fetchDistribution
        let started = DispatchTime.now()
        let distributionLookup = Task { await fetchDistribution() }

        guard case .finished(let raw) = await Self.timed(milliseconds: timeout, { await fetch() }) else {
            distributionLookup.cancel()
            throw StorefrontError.timeout(milliseconds: timeout)
        }

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000
        let distribution: AppDistribution
        switch await Self.timed(milliseconds: max(0, timeout - elapsed), { await distributionLookup.value }) {
        case .finished(let value):
            distribution = value
        case .timedOut:
            distributionLookup.cancel()
            Self.logger.error("The app distributor was not reported within \(Int(timeout)) ms, reporting source 'other'.")
            distribution = .other
        }

        guard let raw = raw else {
            throw StorefrontError.unavailable(distribution: distribution)
        }
        return StorefrontInfo(raw: raw, distribution: distribution)
    }

    /// `StoreKit.Storefront.current`, reduced to the values the plugin needs.
    @Sendable
    public static func fetchFromStoreKit() async -> RawStorefront? {
        guard let storefront = await Storefront.current else {
            return nil
        }
        return RawStorefront(countryCode: storefront.countryCode, id: storefront.id)
    }

    /// Outcome of racing an operation against a timer.
    enum Timed<T: Sendable>: Sendable {
        case finished(T)
        case timedOut
    }

    /// Races `operation` against a timer of `milliseconds`.
    ///
    /// Deliberately not a task group: a group waits for its children to react
    /// to cancellation, and neither StoreKit nor MarketplaceKit promise that
    /// (MarketplaceKit never returns in hostless test bundles on the
    /// simulator). Here the timer wins regardless and the operation is left
    /// running, so the caller's promise always settles.
    static func timed<T: Sendable>(
        milliseconds: Double,
        _ operation: @escaping @Sendable () async -> T
    ) async -> Timed<T> {
        await withCheckedContinuation { (continuation: CheckedContinuation<Timed<T>, Never>) in
            let once = ResumeOnce(continuation)
            let work = Task { await operation() }
            let timer = Task {
                let nanoseconds = UInt64(max(0, milliseconds) * 1_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                if !Task.isCancelled {
                    work.cancel()
                    once.resume(.timedOut)
                }
            }
            Task {
                let value = await work.value
                once.resume(.finished(value))
                timer.cancel()
            }
        }
    }

    /// Resumes a continuation exactly once, whichever racer gets there first.
    private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, Never>?

        init(_ continuation: CheckedContinuation<T, Never>) {
            self.continuation = continuation
        }

        func resume(_ value: T) {
            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()
            continuation?.resume(returning: value)
        }
    }
}
