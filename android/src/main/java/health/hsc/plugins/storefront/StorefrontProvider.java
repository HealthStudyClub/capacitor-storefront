package health.hsc.plugins.storefront;

import androidx.annotation.NonNull;

/** Source of the storefront. The plugin uses {@link PlayBillingStorefrontProvider}; tests inject fakes. */
public interface StorefrontProvider {
    /**
     * Looks the storefront up and reports exactly one of the callback methods, on any thread.
     *
     * @param timeoutMs how long to wait for the store before failing with {@link StorefrontException#CODE_TIMEOUT}
     */
    void getStorefront(long timeoutMs, @NonNull Callback callback);

    interface Callback {
        void onSuccess(@NonNull StorefrontInfo info);

        void onError(@NonNull StorefrontException error);
    }
}
