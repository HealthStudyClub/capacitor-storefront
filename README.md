# @healthstudyclub/capacitor-storefront

Capacitor plugin that reads the storefront (store country) the device's app store account is assigned to.

| Platform | Source                                                                 | Requirements                                              |
| -------- | ---------------------------------------------------------------------- | --------------------------------------------------------- |
| iOS      | StoreKit 2 [`Storefront.current`](https://developer.apple.com/documentation/storekit/storefront/current) | iOS 15+ (Capacitor 8)                                     |
| Android  | not available yet, rejects with `UNIMPLEMENTED`                        | see [Android](#android)                                   |
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
  console.log(storefront.id); // "143443"
  console.log(storefront.source); // "appStore"
} catch (error) {
  switch ((error as { code?: string }).code) {
    case 'UNAVAILABLE':
      // no App Store account on the device
      break;
    case 'TIMEOUT':
      // the store did not answer within `timeout` ms
      break;
    case 'UNIMPLEMENTED':
      // running on Android or the web
      break;
  }
}
```

The country code is normalised to ISO 3166-1 alpha-2, and the App Store storefront id is reported alongside it.

## Platform notes

### iOS

`Storefront.current` is read through StoreKit 2. It reflects the App Store account signed in on the device, or, when the app runs with a StoreKit configuration file, the storefront selected in Xcode. It does not need any capability or entitlement.

### Android

Android is not supported for now. Google Play only reports the storefront through the Play Billing Library, and that library adds the `com.android.vending.BILLING` permission to every app that includes it. To keep apps free of that permission, the package does not ship or register its Android implementation: `npx cap sync android` skips the plugin and `getStorefront()` rejects with `UNIMPLEMENTED` on Android.

The Play Billing implementation (`BillingClient.getBillingConfigAsync`) and its emulator tests stay in `android/` so Android support can be switched back on by restoring `capacitor.android` and the `android/` entries of `files` in `package.json`.

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
- the reader's mapping, `UNAVAILABLE` and `TIMEOUT` behaviour with an injected StoreKit stand-in,
- the real StoreKit path on the simulator: the plugin has to read back whatever `Storefront.current` reports, and a [StoreKit Testing](https://developer.apple.com/documentation/storekittest) session selects specific storefronts (`DEU`, `USA`, `GBR`, `CHE`) that the plugin has to read through `Storefront.current`.

#### Known Apple bug: StoreKit Testing on iOS 26.3+ simulators

Since the iOS 26.3 simulator runtime, `SKTestSession` cannot apply its StoreKit configuration when tests are started with `xcodebuild` instead of the Xcode IDE. Every call logs `Error Domain=SKInternalErrorDomain Code=3` and the simulator keeps its default storefront (`USA`), so tests that select another storefront fail. Apple tracks this as FB22237318; the iOS 26.5 release notes list it as fixed, but the error persists on iOS 26.5.1 with Xcode 26.6 and Apple's DTS states there is no workaround ([forum thread](https://developer.apple.com/forums/thread/826971)). iOS 26.2 and older runtimes are not affected.

The plugin handles it in two places:

1. `scripts/test-ios.sh` picks the newest iPhone simulator whose runtime is at most `IOS_MAX_RUNTIME` (default `26.2`) and only falls back to newer runtimes when no such simulator exists. GitHub's macOS runners ship iOS 26.2 next to the current runtime, so CI runs the full suite. Set `IOS_MAX_RUNTIME=99` to force the newest runtime.
2. The storefront-switching tests wait up to 5 s for the override to take effect and otherwise skip with a message naming the bug, instead of failing. `testReadsTheStorefrontTheSimulatorReports` does not depend on the override and always verifies the real StoreKit read path.

### Android emulator tests

`scripts/test-android.sh` runs `./gradlew connectedDebugAndroidTest` against whatever `adb` sees. The tests in `android/src/androidTest` cover:

- the alpha-2 to alpha-3 mapping and the JSON payloads,
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

- iOS: `StoreKit.Storefront.current` (StoreKit 2).
- Android: not available yet, rejects with code `UNIMPLEMENTED`.
- Web: not available, rejects with code `UNIMPLEMENTED`.

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code><a href="#getstorefrontoptions">GetStorefrontOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#storefrontinfo">StorefrontInfo</a>&gt;</code>

**Since:** 0.1.0

--------------------


### Interfaces


#### StorefrontInfo

| Prop               | Type                                                          | Description                                                                                                                                                                                                                                                                             | Since |
| ------------------ | ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`countryCode`**  | <code>string</code>                                           | ISO 3166-1 alpha-2 country code of the storefront, upper case (e.g. `"DE"`). On iOS this is derived from the alpha-3 code that StoreKit reports. Should StoreKit ever report a code the plugin does not know, the raw alpha-3 value is returned here unchanged.                         | 0.1.0 |
| **`countryCode3`** | <code>string</code>                                           | ISO 3166-1 alpha-3 country code of the storefront, upper case (e.g. `"DEU"`). On iOS this is the raw value of `Storefront.current.countryCode`. On Android it is derived from the alpha-2 code Google Play reports and is omitted when the device's locale data does not know the code. | 0.1.0 |
| **`id`**           | <code>string</code>                                           | Platform specific storefront identifier. - iOS: the App Store storefront id (`Storefront.current.id`, e.g. `"143443"` for Germany). - Android: not available.                                                                                                                           | 0.1.0 |
| **`source`**       | <code><a href="#storefrontsource">StorefrontSource</a></code> | The store that answered.                                                                                                                                                                                                                                                                | 0.1.0 |


#### GetStorefrontOptions

| Prop          | Type                | Description                                                                                         | Default            | Since |
| ------------- | ------------------- | --------------------------------------------------------------------------------------------------- | ------------------ | ----- |
| **`timeout`** | <code>number</code> | Maximum time in milliseconds to wait for the store before the call is rejected with code `TIMEOUT`. | <code>10000</code> | 0.1.0 |


### Type Aliases


#### StorefrontSource

The store that answered the storefront request.

- `appStore`: Apple App Store, read through StoreKit (`Storefront.current`).
- `playBilling`: Google Play, read through the Play Billing Library
  (`BillingClient.getBillingConfigAsync`).

<code>'appStore' | 'playBilling'</code>

</docgen-api>
