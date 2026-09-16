import Foundation
import os
#if canImport(MarketplaceKit)
import MarketplaceKit
#endif

// This file deliberately does not import UIKit (directly or through Capacitor):
// MarketplaceKit's `AppDistributor` is not found in files that do.

/// The channel the app was distributed through, as MarketplaceKit reports it.
///
/// `source` is what JavaScript sees in `StorefrontInfo.source`, `installer` the
/// bundle identifier of the alternative marketplace for `marketplace` installs.
public struct AppDistribution: Equatable, Sendable {
    /// `"appStore"`, `"testFlight"`, `"marketplace"`, `"web"` or `"other"`.
    public let source: String
    /// Bundle identifier of the app that installed this app, when known.
    public let installer: String?

    public init(source: String, installer: String? = nil) {
        self.source = source
        self.installer = installer
    }

    /// Installed from the App Store, or running on iOS before 17.4 where no other channel exists.
    public static let appStore = AppDistribution(source: "appStore")
    /// Installed through TestFlight.
    public static let testFlight = AppDistribution(source: "testFlight")
    /// Installed through web distribution (EU).
    public static let web = AppDistribution(source: "web")
    /// Not attributable: development, ad hoc or enterprise builds, or MarketplaceKit failed.
    public static let other = AppDistribution(source: "other")

    /// Installed from the alternative app marketplace with the given bundle identifier (EU).
    public static func marketplace(_ bundleIdentifier: String) -> AppDistribution {
        AppDistribution(source: "marketplace", installer: bundleIdentifier)
    }

    /// The keys this contributes to the resolved payload and to `error.data`.
    public var dictionary: [String: Any] {
        var dictionary: [String: Any] = ["source": source]
        if let installer = installer {
            dictionary["installer"] = installer
        }
        return dictionary
    }

    private static let logger = Logger(subsystem: "health.hsc.storefront", category: "Storefront")

    /// `MarketplaceKit.AppDistributor.current`. Before iOS 17.4 alternative
    /// distribution does not exist, so the app can only have come from the App
    /// Store (or TestFlight, which is not distinguishable there). Should
    /// MarketplaceKit fail, the distribution is reported as `other`.
    @Sendable
    public static func fetchFromMarketplaceKit() async -> AppDistribution {
        #if canImport(MarketplaceKit)
        guard #available(iOS 17.4, *) else {
            return .appStore
        }
        do {
            return AppDistribution(distributor: try await MarketplaceKit.AppDistributor.current)
        } catch {
            logger.error("MarketplaceKit could not determine the app distributor: \(String(describing: error), privacy: .public)")
            return .other
        }
        #else
        return .appStore
        #endif
    }

    #if canImport(MarketplaceKit)
    @available(iOS 17.4, *)
    public init(distributor: MarketplaceKit.AppDistributor) {
        switch distributor {
        case .appStore:
            self = .appStore
        case .testFlight:
            self = .testFlight
        case .marketplace(let bundleIdentifier):
            self = .marketplace(bundleIdentifier)
        case .other:
            self = .other
        default:
            // `.web` exists from iOS 17.5 on and cannot be matched in a 17.4 context.
            if #available(iOS 17.5, *), case .web = distributor {
                self = .web
            } else {
                self = .other
            }
        }
    }
    #endif
}
