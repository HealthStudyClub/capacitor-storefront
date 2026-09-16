import Foundation
import Capacitor

/// Capacitor bridge for the `Storefront` plugin.
///
/// See https://capacitorjs.com/docs/plugins/ios for the plugin development guide.
@objc(StorefrontPlugin)
public class StorefrontPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "StorefrontPlugin"
    public let jsName = "Storefront"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getStorefront", returnType: CAPPluginReturnPromise)
    ]
    private let reader = StorefrontReader()

    @objc func getStorefront(_ call: CAPPluginCall) {
        let timeout = Self.timeout(from: call.getDouble("timeout"))
        let reader = self.reader
        Task {
            do {
                let info = try await reader.read(timeout: timeout)
                call.resolve(info.dictionary)
            } catch let error as StorefrontError {
                call.reject(error.message, error.code, error, error.data)
            } catch {
                call.reject(error.localizedDescription, StorefrontError.unavailable(distribution: nil).code, error)
            }
        }
    }

    /// Falls back to the default for missing, non-finite or non-positive values.
    static func timeout(from option: Double?) -> Double {
        guard let option = option, option.isFinite, option > 0 else {
            return StorefrontReader.defaultTimeout
        }
        return option
    }
}
