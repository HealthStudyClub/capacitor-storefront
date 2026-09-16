package health.hsc.plugins.storefront;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.android.billingclient.api.BillingResult;
import com.getcapacitor.JSObject;

/** A failed storefront lookup. {@link #getCode()} is what JavaScript sees as {@code error.code}. */
public final class StorefrontException extends Exception {

    /** Google Play Billing is not available or did not report a storefront. */
    public static final String CODE_UNAVAILABLE = "UNAVAILABLE";
    /** Google Play did not answer within the timeout. */
    public static final String CODE_TIMEOUT = "TIMEOUT";

    private final String code;
    private final Integer responseCode;
    private final String debugMessage;
    private final String installer;

    /**
     * @param responseCode Play Billing response code, if the failure came from Play Billing.
     * @param debugMessage Play Billing debug message, if any.
     * @param installer package that installed the app, or {@code null} when Android did not record one.
     */
    public StorefrontException(
        @NonNull String code,
        @NonNull String message,
        @Nullable Integer responseCode,
        @Nullable String debugMessage,
        @Nullable String installer
    ) {
        super(message);
        this.code = code;
        this.responseCode = responseCode;
        this.debugMessage = debugMessage;
        this.installer = installer;
    }

    @NonNull
    public static StorefrontException unavailable(@NonNull String message, @Nullable String installer) {
        return new StorefrontException(CODE_UNAVAILABLE, message, null, null, installer);
    }

    @NonNull
    public static StorefrontException unavailable(@NonNull String message, @NonNull BillingResult result, @Nullable String installer) {
        String debug = result.getDebugMessage();
        String detail = message + " (Play Billing response code " + result.getResponseCode() + (debug.isEmpty() ? "" : ": " + debug) + ")";
        return new StorefrontException(CODE_UNAVAILABLE, detail, result.getResponseCode(), debug.isEmpty() ? null : debug, installer);
    }

    @NonNull
    public static StorefrontException timeout(long timeoutMs, @Nullable String installer) {
        return new StorefrontException(
            CODE_TIMEOUT,
            "Google Play did not report a storefront within " + timeoutMs + " ms.",
            null,
            null,
            installer
        );
    }

    @NonNull
    public String getCode() {
        return code;
    }

    /** The Play Billing response code, if the failure came from Play Billing. */
    @Nullable
    public Integer getResponseCode() {
        return responseCode;
    }

    /** The Play Billing debug message, if any. */
    @Nullable
    public String getDebugMessage() {
        return debugMessage;
    }

    /** Package that installed the app (e.g. {@code com.android.vending}), or {@code null} when unknown. */
    @Nullable
    public String getInstaller() {
        return installer;
    }

    /** Extra data for the rejected call, or {@code null} when there is none. */
    @Nullable
    public JSObject toData() {
        if (responseCode == null && debugMessage == null && installer == null) {
            return null;
        }
        JSObject data = new JSObject();
        if (responseCode != null) {
            data.put("responseCode", responseCode);
        }
        if (debugMessage != null) {
            data.put("debugMessage", debugMessage);
        }
        if (installer != null) {
            data.put("installer", installer);
        }
        return data;
    }
}
