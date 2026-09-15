package de.healthstudyclub.plugins.storefront;

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

    public StorefrontException(
        @NonNull String code,
        @NonNull String message,
        @Nullable Integer responseCode,
        @Nullable String debugMessage
    ) {
        super(message);
        this.code = code;
        this.responseCode = responseCode;
        this.debugMessage = debugMessage;
    }

    @NonNull
    public static StorefrontException unavailable(@NonNull String message) {
        return new StorefrontException(CODE_UNAVAILABLE, message, null, null);
    }

    @NonNull
    public static StorefrontException unavailable(@NonNull String message, @NonNull BillingResult result) {
        String debug = result.getDebugMessage();
        String detail = message + " (Play Billing response code " + result.getResponseCode() + (debug.isEmpty() ? "" : ": " + debug) + ")";
        return new StorefrontException(CODE_UNAVAILABLE, detail, result.getResponseCode(), debug.isEmpty() ? null : debug);
    }

    @NonNull
    public static StorefrontException timeout(long timeoutMs) {
        return new StorefrontException(CODE_TIMEOUT, "Google Play did not report a storefront within " + timeoutMs + " ms.", null, null);
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

    /** Extra data for the rejected call, or {@code null} when there is none. */
    @Nullable
    public JSObject toData() {
        if (responseCode == null && debugMessage == null) {
            return null;
        }
        JSObject data = new JSObject();
        if (responseCode != null) {
            data.put("responseCode", responseCode);
        }
        if (debugMessage != null) {
            data.put("debugMessage", debugMessage);
        }
        return data;
    }
}
