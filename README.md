# @healthstudyclub/capacitor-storefront

Capacitor plugin that reads the storefront (store country) the device's app store account is assigned to.

| Platform | Source                                                                 | Requirements                                              |
| -------- | ---------------------------------------------------------------------- | --------------------------------------------------------- |
| iOS      | StoreKit 2 [`Storefront.current`](https://developer.apple.com/documentation/storekit/storefront/current), MarketplaceKit [`AppDistributor.current`](https://developer.apple.com/documentation/marketplacekit/appdistributor) for the `source` | iOS 15+ (Capacitor 8), `source` other than `appStore` needs iOS 17.4+ |
| Android  | Play Billing [`BillingClient.getBillingConfigAsync`](https://developer.android.com/reference/com/android/billingclient/api/BillingClient#getBillingConfigAsync(com.android.billingclient.api.GetBillingConfigParams,%20com.android.billingclient.api.BillingConfigResponseListener)) | Google Play Store and a signed in Google account on the device |
| Web      | not available, rejects with `UNIMPLEMENTED`                            |                                                           |

## Install

```bash
npm install @healthstudyclub/capacitor-storefront
npx cap sync
```

Requires Capacitor 8 or newer.

## Usage

```ts
import { Storefront } from '@healthstudyclub/capacitor-storefront';

try {
  const storefront = await Storefront.getStorefront();
  console.log(storefront.countryCode); // "DE"
  console.log(storefront.countryCode3); // "DEU"
  console.log(storefront.id); // "143443" on iOS, undefined on Android
  console.log(storefront.source); // "appStore" | "testFlight" | "marketplace" | "web" | "other" | "playBilling"
  console.log(storefront.installer); // "com.android.vending" on Android, the marketplace's bundle id on iOS, else undefined
} catch (error) {
  switch ((error as { code?: string }).code) {
    case 'UNAVAILABLE':
      // no store account / no Google Play on the device
      break;
    case 'TIMEOUT':
      // the store did not answer within `timeout` ms
      break;
    case 'UNIMPLEMENTED':
      // running on the web
      break;
  }
}
```

The country code is normalised to ISO 3166-1 alpha-2 on both platforms. `source` tells which store or channel the app was distributed through, `installer` identifies the installing app when the platform knows it (see the platform notes). iOS additionally reports the App Store storefront id. When the lookup fails, `error.data` carries `source` and `installer` on iOS, and `installer` together with the Play Billing `responseCode` and `debugMessage` on Android.

## Platform notes

### iOS

`Storefront.current` is read through StoreKit 2. It reflects the App Store account signed in on the device, or, when the app runs with a StoreKit configuration file, the storefront selected in Xcode. It does not need any capability or entitlement.

`source` comes from MarketplaceKit's [`AppDistributor.current`](https://developer.apple.com/documentation/marketplacekit/appdistributor) on iOS 17.4 and newer: `appStore`, `testFlight`, `marketplace` (with the marketplace's bundle identifier in `installer`), `web` (iOS 17.5 and newer) or `other` for builds iOS cannot attribute (development, ad hoc, enterprise) and when MarketplaceKit fails to answer. Before iOS 17.4 alternative distribution does not exist, so the plugin reports `appStore` there. MarketplaceKit is weak-linked and the plugin keeps working on iOS 15 and 16. The distribution lookup shares the call's `timeout`: when MarketplaceKit has not answered by then, the storefront is still returned with `source` set to `other`. That is what happens in hostless XCTest bundles on the simulator, where `AppDistributor.current` never answers. Apps distributed outside the App Store may get no storefront at all; the `UNAVAILABLE` error then still carries `source` and `installer` in `error.data`.

### Android

Google Play reports the storefront through the Play Billing Library (version 9.1.0 by default, override with `playBillingVersion` in your app's `variables.gradle`). The plugin opens a billing connection for each call and closes it again once the answer arrived, so it does not interfere with other billing libraries in the app. Google Play needs the Play Store app and a signed in Google account, otherwise the call rejects with `UNAVAILABLE`.

Google Play answers whenever the Play Store and a Google account are on the device, regardless of where the app itself was installed from, so `source` is always `playBilling` on Android. To tell installs apart, every result and every `error.data` object carries `installer`, the package that installed the app as recorded by Android: `com.android.vending` for Google Play, `com.amazon.venezia` for the Amazon Appstore, `com.sec.android.app.samsungapps` for the Galaxy Store, and so on. It is read through `PackageManager.getInstallSourceInfo` on Android 11 and newer and `PackageManager.getInstallerPackageName` before that, and omitted when Android did not record an installer, e.g. for `adb` installs or APKs installed from a file.

## Development

```bash
npm install
npm run build        # docgen + TypeScript + rollup bundle
npm run lint         # eslint, prettier, swiftlint
npm run test:ios     # XCTest on an iOS simulator (macOS with Xcode)
npm run test:android # instrumented tests on the connected Android emulator/device
```

### iOS simulator tests

`scripts/test-ios.sh` runs the Swift package's test suite with `xcodebuild test` on an iPhone simulator (override with `IOS_SIMULATOR_NAME` or `IOS_SIMULATOR_ID`). The tests in `ios/Tests/StorefrontPluginTests` cover:

- the ISO 3166-1 alpha-3 to alpha-2 mapping,
- the mapping of MarketplaceKit's `AppDistributor` to `source` and `installer`, and that the real MarketplaceKit path settles within the timeout with a documented source,
- the reader's mapping, `UNAVAILABLE` and `TIMEOUT` behaviour with injected StoreKit and MarketplaceKit stand-ins, including stand-ins that never answer,
- the real StoreKit path on the simulator: the plugin has to read back whatever `Storefront.current` reports, and a [StoreKit Testing](https://developer.apple.com/documentation/storekittest) session selects specific storefronts (`DEU`, `USA`, `GBR`, `CHE`) that the plugin has to read through `Storefront.current`.

#### Known Apple bug: StoreKit Testing on iOS 26.3+ simulators

Since the iOS 26.3 simulator runtime, `SKTestSession` cannot apply its StoreKit configuration when tests are started with `xcodebuild` instead of the Xcode IDE. Every call logs `Error Domain=SKInternalErrorDomain Code=3` and the simulator keeps its default storefront (`USA`), so tests that select another storefront fail. Apple tracks this as FB22237318; the iOS 26.5 release notes list it as fixed, but the error persists on iOS 26.5.1 with Xcode 26.6 and Apple's DTS states there is no workaround ([forum thread](https://developer.apple.com/forums/thread/826971)). iOS 26.2 and older runtimes are not affected.

The plugin handles it in two places:

1. `scripts/test-ios.sh` picks the newest iPhone simulator whose runtime is at most `IOS_MAX_RUNTIME` (default `26.2`) and only falls back to newer runtimes when no such simulator exists. GitHub's macOS runners ship iOS 26.2 next to the current runtime, so CI runs the full suite. Set `IOS_MAX_RUNTIME=99` to force the newest runtime.
2. The storefront-switching tests wait up to 5 s for the override to take effect and otherwise skip with a message naming the bug, instead of failing. `testReadsTheStorefrontTheSimulatorReports` does not depend on the override and always verifies the real StoreKit read path.

### Android emulator tests

`scripts/test-android.sh` runs `./gradlew connectedDebugAndroidTest` against whatever `adb` sees. The tests in `android/src/androidTest` cover:

- the alpha-2 to alpha-3 mapping, the installer package lookup and the JSON payloads,
- the plugin's bridge layer with a fake provider (resolve, reject, timeout option),
- the real Play Billing path. Emulators without Google Play cannot report a storefront, so this test asserts the contract that holds everywhere: the lookup settles exactly once, within the timeout, with either a well formed storefront or a well formed `UNAVAILABLE`/`TIMEOUT` error.

## Continuous integration and publishing

- `.github/workflows/ci.yml` runs on every pull request to `main` and on pushes to `main`: web build and lint, the iOS simulator tests on a macOS runner, and the Android instrumented tests on an emulator (API 34, x86_64, KVM) on a Linux runner.
- `.github/workflows/release.yml` runs the same tests and then publishes to npmjs when a GitHub release is published (or on manual dispatch, optionally as a dry run). The release tag has to match the version in `package.json`, e.g. tag `v0.1.0` for version `0.1.0`.

Publishing uses [npm Trusted Publishing](https://docs.npmjs.com/trusted-publishers): the workflow authenticates with a short-lived OIDC token from GitHub, so no npm token is stored in the repository and provenance attestations are generated automatically. One-time setup on npmjs.com, under the package's settings, "Trusted Publisher", GitHub Actions:

| Field                | Value                  |
| -------------------- | ---------------------- |
| Organization or user | `HealthStudyClub`      |
| Repository           | `capacitor-storefront` |
| Workflow filename    | `release.yml`          |
| Environment          | leave empty            |

If npmjs.com only lets you add a trusted publisher to a package that already exists, do the very first publish with a short-lived granular access token (publish permission for the package) stored as the repository secret `NPM_TOKEN`; the workflow uses that secret when it is present. Afterwards configure the trusted publisher and delete both the token and the secret.

Release checklist:

1. Bump `version` in `package.json` and commit to `main`.
2. Create a GitHub release with tag `v<version>`.
3. The release workflow tests and publishes.

## API

<docgen-index>

* [`getStorefront(...)`](#getstorefront)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### getStorefront(...)

```typescript
getStorefront(options?: GetStorefrontOptions | undefined) => Promise<StorefrontInfo>
```

Read the storefront (store country) the device's app store account is
assigned to.

- iOS: `StoreKit.Storefront.current` (StoreKit 2), plus MarketplaceKit's
  `AppDistributor.current` for the `source` (iOS 17.4 and newer).
- Android: `BillingClient.getBillingConfigAsync` (Play Billing Library),
  which requires the Google Play Store and a signed in Google account,
  plus the installer package from `PackageManager`.
- Web: not available, rejects with code `UNIMPLEMENTED`.

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code><a href="#getstorefrontoptions">GetStorefrontOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#storefrontinfo">StorefrontInfo</a>&gt;</code>

**Since:** 0.1.0

--------------------


### Interfaces


#### StorefrontInfo

| Prop               | Type                                                          | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Since |
| ------------------ | ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`countryCode`**  | <code>string</code>                                           | ISO 3166-1 alpha-2 country code of the storefront, upper case (e.g. `"DE"`). On iOS this is derived from the alpha-3 code that StoreKit reports. Should StoreKit ever report a code the plugin does not know, the raw alpha-3 value is returned here unchanged.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | 0.1.0 |
| **`countryCode3`** | <code>string</code>                                           | ISO 3166-1 alpha-3 country code of the storefront, upper case (e.g. `"DEU"`). On iOS this is the raw value of `Storefront.current.countryCode`. On Android it is derived from the alpha-2 code Google Play reports and is omitted when the device's locale data does not know the code.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | 0.1.0 |
| **`id`**           | <code>string</code>                                           | Platform specific storefront identifier. - iOS: the App Store storefront id (`Storefront.current.id`, e.g. `"143443"` for Germany). - Android: not available.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | 0.1.0 |
| **`source`**       | <code><a href="#storefrontsource">StorefrontSource</a></code> | The store or channel the app was distributed through, see {@link <a href="#storefrontsource">StorefrontSource</a>}. Version 0.1.0 only reported `appStore` and `playBilling`; since 0.2.0 iOS distinguishes App Store, TestFlight, alternative marketplace and web distribution.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | 0.2.0 |
| **`installer`**    | <code>string</code>                                           | Identifier of the app that installed this app. - iOS: the bundle identifier of the alternative app marketplace when `source` is `marketplace`; not available for other sources. - Android: the installer package name recorded by the package manager (e.g. `"com.android.vending"` for Google Play, `"com.amazon.venezia"` for the Amazon Appstore), read through `PackageManager.getInstallSourceInfo` (Android 11 and newer) or `PackageManager.getInstallerPackageName` (older versions). Google Play Billing reports the storefront of the Google account on the device even when the app was not installed from Google Play, so this field tells such installs apart. Omitted when the platform did not record an installer, e.g. for installs through `adb` or from an APK file. The same value is reported in `error.data` when the lookup fails. | 0.2.0 |


#### GetStorefrontOptions

| Prop          | Type                | Description                                                                                                                                                                                                                                                                                        | Default            | Since |
| ------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----- |
| **`timeout`** | <code>number</code> | Maximum time in milliseconds to wait for the store before the call is rejected with code `TIMEOUT`. On iOS the distribution lookup behind `source` shares this budget: when MarketplaceKit has not answered by the time it expires, the storefront is still returned with `source` set to `other`. | <code>10000</code> | 0.1.0 |


### Type Aliases


#### StorefrontSource

The store or channel the app was distributed through.

On iOS this comes from MarketplaceKit's `AppDistributor.current` (iOS 17.4
and newer). Before iOS 17.4 no other channel than the App Store exists, so
`appStore` is reported (TestFlight builds included). On Android the
storefront is always read through Google Play Billing, so `playBilling` is
reported regardless of where the app was installed from; use
{@link <a href="#storefrontinfo">StorefrontInfo.installer</a>} to tell installs apart there.

- `appStore`: Apple App Store.
- `testFlight`: TestFlight (iOS 17.4 and newer).
- `marketplace`: an alternative app marketplace (EU, iOS 17.4 and newer).
  `installer` holds the marketplace's bundle identifier.
- `web`: web distribution (EU, iOS 17.5 and newer).
- `other`: iOS could not attribute the installation, e.g. development, ad hoc
  and enterprise builds, or MarketplaceKit failed to answer within the
  timeout.
- `playBilling`: Google Play, read through the Play Billing Library
  (`BillingClient.getBillingConfigAsync`).

`testFlight`, `marketplace`, `web` and `other` are reported since 0.2.0.

<code>'appStore' | 'testFlight' | 'marketplace' | 'web' | 'other' | 'playBilling'</code>

</docgen-api>
