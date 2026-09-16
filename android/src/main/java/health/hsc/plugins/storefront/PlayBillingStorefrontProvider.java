package health.hsc.plugins.storefront;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingConfig;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.GetBillingConfigParams;
import com.android.billingclient.api.PendingPurchasesParams;
import com.getcapacitor.Logger;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Reads the Google Play storefront through the Play Billing Library's billing configuration
 * ({@code BillingClient.getBillingConfigAsync}), the Android counterpart of StoreKit's
 * {@code Storefront.current}.
 *
 * <p>This needs the Google Play Store and a signed in Google account on the device. Emulators
 * without Google Play fail with {@link StorefrontException#CODE_UNAVAILABLE}.
 *
 * <p>Google Play answers regardless of where the app itself was installed from, so every result
 * and error also carries the package that installed the app (see {@link InstallSource}).
 */
public final class PlayBillingStorefrontProvider implements StorefrontProvider {

    private static final String TAG = "Storefront";

    private final Context context;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public PlayBillingStorefrontProvider(@NonNull Context context) {
        this.context = context.getApplicationContext();
    }

    @Override
    public void getStorefront(long timeoutMs, @NonNull Callback callback) {
        Lookup lookup = new Lookup(timeoutMs, callback);
        mainHandler.post(lookup::start);
    }

    /** One lookup: a fresh billing connection that is closed again once it settled. */
    private final class Lookup implements BillingClientStateListener {

        private final long timeoutMs;
        private final Callback callback;
        private final AtomicBoolean settled = new AtomicBoolean(false);
        private final Runnable onTimeout;

        @Nullable
        private final String installer;

        private volatile BillingClient client;

        Lookup(long timeoutMs, Callback callback) {
            this.timeoutMs = timeoutMs;
            this.callback = callback;
            this.installer = InstallSource.installer(context);
            this.onTimeout = () -> fail(StorefrontException.timeout(timeoutMs, installer));
        }

        void start() {
            mainHandler.postDelayed(onTimeout, timeoutMs);
            try {
                client = BillingClient.newBuilder(context)
                    // Purchases are not handled by this plugin, but the builder insists on a listener.
                    .setListener((billingResult, purchases) -> {})
                    .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
                    .build();
                client.startConnection(this);
            } catch (RuntimeException e) {
                Logger.error(TAG, "Could not connect to Google Play Billing", e);
                fail(StorefrontException.unavailable("Could not connect to Google Play Billing: " + e.getMessage(), installer));
            }
        }

        @Override
        public void onBillingSetupFinished(@NonNull BillingResult result) {
            BillingClient connected = client;
            if (connected == null || settled.get()) {
                return; // already settled (e.g. timed out) and closed
            }
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                fail(StorefrontException.unavailable("Google Play Billing is not available", result, installer));
                return;
            }
            try {
                connected.getBillingConfigAsync(GetBillingConfigParams.newBuilder().build(), this::onBillingConfig);
            } catch (RuntimeException e) {
                Logger.error(TAG, "getBillingConfigAsync failed", e);
                fail(StorefrontException.unavailable("Google Play Billing could not be queried: " + e.getMessage(), installer));
            }
        }

        private void onBillingConfig(@NonNull BillingResult result, @Nullable BillingConfig config) {
            if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                fail(StorefrontException.unavailable("Google Play did not report a storefront", result, installer));
                return;
            }
            String countryCode = config == null ? null : config.getCountryCode();
            if (countryCode == null || countryCode.trim().isEmpty()) {
                fail(StorefrontException.unavailable("Google Play reported an empty storefront country code", installer));
                return;
            }
            succeed(StorefrontInfo.fromPlayCountryCode(countryCode, installer));
        }

        @Override
        public void onBillingServiceDisconnected() {
            fail(StorefrontException.unavailable("Google Play Billing service disconnected before it reported a storefront", installer));
        }

        private void succeed(StorefrontInfo info) {
            if (settle()) {
                callback.onSuccess(info);
            }
        }

        private void fail(StorefrontException error) {
            if (settle()) {
                callback.onError(error);
            }
        }

        /** Marks the lookup as done and releases the billing connection. Returns false if it was done already. */
        private boolean settle() {
            if (!settled.compareAndSet(false, true)) {
                return false;
            }
            mainHandler.removeCallbacks(onTimeout);
            BillingClient toClose = client;
            client = null;
            if (toClose != null) {
                try {
                    toClose.endConnection();
                } catch (RuntimeException e) {
                    Logger.warn(TAG, "endConnection failed: " + e.getMessage());
                }
            }
            return true;
        }
    }
}
