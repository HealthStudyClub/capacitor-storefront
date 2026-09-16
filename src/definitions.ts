/**
 * The store or channel the app was distributed through.
 *
 * On iOS this comes from MarketplaceKit's `AppDistributor.current` (iOS 17.4
 * and newer). Before iOS 17.4 no other channel than the App Store exists, so
 * `appStore` is reported (TestFlight builds included). On Android the
 * storefront is always read through Google Play Billing, so `playBilling` is
 * reported regardless of where the app was installed from; use
 * {@link StorefrontInfo.installer} to tell installs apart there.
 *
 * - `appStore`: Apple App Store.
 * - `testFlight`: TestFlight (iOS 17.4 and newer).
 * - `marketplace`: an alternative app marketplace (EU, iOS 17.4 and newer).
 *   `installer` holds the marketplace's bundle identifier.
 * - `web`: web distribution (EU, iOS 17.5 and newer).
 * - `other`: iOS could not attribute the installation, e.g. development, ad hoc
 *   and enterprise builds, or MarketplaceKit failed to answer within the
 *   timeout.
 * - `playBilling`: Google Play, read through the Play Billing Library
 *   (`BillingClient.getBillingConfigAsync`).
 *
 * `testFlight`, `marketplace`, `web` and `other` are reported since 0.2.0.
 */
export type StorefrontSource = 'appStore' | 'testFlight' | 'marketplace' | 'web' | 'other' | 'playBilling';

/**
 * Error codes reported in the `code` property of the rejected error.
 *
 * - `UNAVAILABLE`: the store did not report a storefront. On iOS
 *   `Storefront.current` returned `nil`; the error carries a `data` object
 *   with the `source` and, for marketplace installs, the `installer` (see
 *   {@link StorefrontInfo}), so the caller still learns where the app came
 *   from. On Android Google Play Billing is not available on the device (no
 *   Play Store, no signed in account, ...) or answered with an error; the
 *   `data` object carries the Play Billing `responseCode` and `debugMessage`
 *   (when the failure came from Play Billing) and the app's `installer` (when
 *   known).
 * - `TIMEOUT`: the store did not answer within the requested timeout. On
 *   Android the `data` object carries the `installer` when known.
 * - `UNIMPLEMENTED`: the plugin is not available on this platform (web).
 */
export type StorefrontErrorCode = 'UNAVAILABLE' | 'TIMEOUT' | 'UNIMPLEMENTED';

export interface StorefrontInfo {
  /**
   * ISO 3166-1 alpha-2 country code of the storefront, upper case (e.g. `"DE"`).
   *
   * On iOS this is derived from the alpha-3 code that StoreKit reports. Should
   * StoreKit ever report a code the plugin does not know, the raw alpha-3
   * value is returned here unchanged.
   *
   * @since 0.1.0
   */
  countryCode: string;

  /**
   * ISO 3166-1 alpha-3 country code of the storefront, upper case (e.g. `"DEU"`).
   *
   * On iOS this is the raw value of `Storefront.current.countryCode`. On
   * Android it is derived from the alpha-2 code Google Play reports and is
   * omitted when the device's locale data does not know the code.
   *
   * @since 0.1.0
   */
  countryCode3?: string;

  /**
   * Platform specific storefront identifier.
   *
   * - iOS: the App Store storefront id (`Storefront.current.id`, e.g. `"143443"` for Germany).
   * - Android: not available.
   *
   * @since 0.1.0
   */
  id?: string;

  /**
   * The store or channel the app was distributed through, see
   * {@link StorefrontSource}. Version 0.1.0 only reported `appStore` and
   * `playBilling`; since 0.2.0 iOS distinguishes App Store, TestFlight,
   * alternative marketplace and web distribution.
   *
   * @since 0.2.0
   */
  source: StorefrontSource;

  /**
   * Identifier of the app that installed this app.
   *
   * - iOS: the bundle identifier of the alternative app marketplace when
   *   `source` is `marketplace`; not available for other sources.
   * - Android: the installer package name recorded by the package manager
   *   (e.g. `"com.android.vending"` for Google Play, `"com.amazon.venezia"` for
   *   the Amazon Appstore), read through `PackageManager.getInstallSourceInfo`
   *   (Android 11 and newer) or `PackageManager.getInstallerPackageName`
   *   (older versions). Google Play Billing reports the storefront of the
   *   Google account on the device even when the app was not installed from
   *   Google Play, so this field tells such installs apart.
   *
   * Omitted when the platform did not record an installer, e.g. for installs
   * through `adb` or from an APK file. The same value is reported in
   * `error.data` when the lookup fails.
   *
   * @since 0.2.0
   */
  installer?: string;
}

export interface GetStorefrontOptions {
  /**
   * Maximum time in milliseconds to wait for the store before the call is
   * rejected with code `TIMEOUT`. On iOS the distribution lookup behind
   * `source` shares this budget: when MarketplaceKit has not answered by the
   * time it expires, the storefront is still returned with `source` set to
   * `other`.
   *
   * @default 10000
   * @since 0.1.0
   */
  timeout?: number;
}

export interface StorefrontPlugin {
  /**
   * Read the storefront (store country) the device's app store account is
   * assigned to.
   *
   * - iOS: `StoreKit.Storefront.current` (StoreKit 2), plus MarketplaceKit's
   *   `AppDistributor.current` for the `source` (iOS 17.4 and newer).
   * - Android: `BillingClient.getBillingConfigAsync` (Play Billing Library),
   *   which requires the Google Play Store and a signed in Google account,
   *   plus the installer package from `PackageManager`.
   * - Web: not available, rejects with code `UNIMPLEMENTED`.
   *
   * @throws Rejects with a `code` of type {@link StorefrontErrorCode}.
   * @since 0.1.0
   */
  getStorefront(options?: GetStorefrontOptions): Promise<StorefrontInfo>;
}
