package health.hsc.plugins.storefront;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/** Capacitor bridge for the {@code Storefront} plugin. */
@CapacitorPlugin(name = "Storefront")
public class StorefrontPlugin extends Plugin {

    /** Default timeout in milliseconds. */
    public static final long DEFAULT_TIMEOUT_MS = 10_000L;

    private StorefrontProvider provider;

    @Override
    public void load() {
        if (provider == null) {
            provider = new PlayBillingStorefrontProvider(getContext());
        }
    }

    /** Replaces the Play Billing backed provider, e.g. with a fake in tests. */
    @VisibleForTesting
    public void setStorefrontProvider(@NonNull StorefrontProvider provider) {
        this.provider = provider;
    }

    @PluginMethod
    public void getStorefront(PluginCall call) {
        if (provider == null) {
            provider = new PlayBillingStorefrontProvider(getContext());
        }
        provider.getStorefront(
            timeout(call.getDouble("timeout")),
            new StorefrontProvider.Callback() {
                @Override
                public void onSuccess(@NonNull StorefrontInfo info) {
                    call.resolve(info.toJSObject());
                }

                @Override
                public void onError(@NonNull StorefrontException error) {
                    call.reject(error.getMessage(), error.getCode(), error, error.toData());
                }
            }
        );
    }

    /** Falls back to the default for missing, non-finite or non-positive values. */
    static long timeout(Double option) {
        if (option == null || option.isNaN() || option.isInfinite() || option <= 0) {
            return DEFAULT_TIMEOUT_MS;
        }
        return Math.max(1L, Math.round(option));
    }
}
