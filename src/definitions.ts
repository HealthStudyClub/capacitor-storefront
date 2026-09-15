/**
 * The store that answered the storefront request.
 *
 * - `appStore`: Apple App Store, read through StoreKit (`Storefront.current`).
 * - `playBilling`: Google Play, read through the Play Billing Library
 *   (`BillingClient.getBillingConfigAsync`).
 */
export type StorefrontSource = 'appStore' | 'playBilling';

/**
 * Error codes reported in the `code` property of the rejected error.
 *
 * - `UNAVAILABLE`: the store did not report a storefront. On iOS
 *   `Storefront.current` returned `nil`, on Android Google Play Billing is
 *   not available on the device (no Play Store, no signed in account, ...)
 *   or answered with an error. On Android the error carries a `data` object
 *   with the Play Billing `responseCode` and `debugMessage`.
 * - `TIMEOUT`: the store did not answer within the requested timeout.
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
   * The store that answered.
   *
   * @since 0.1.0
   */
  source: StorefrontSource;
}

export interface GetStorefrontOptions {
  /**
   * Maximum time in milliseconds to wait for the store before the call is
   * rejected with code `TIMEOUT`.
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
   * - iOS: `StoreKit.Storefront.current` (StoreKit 2).
   * - Android: `BillingClient.getBillingConfigAsync` (Play Billing Library),
   *   which requires the Google Play Store and a signed in Google account.
   * - Web: not available, rejects with code `UNIMPLEMENTED`.
   *
   * @throws Rejects with a `code` of type {@link StorefrontErrorCode}.
   * @since 0.1.0
   */
  getStorefront(options?: GetStorefrontOptions): Promise<StorefrontInfo>;
}
