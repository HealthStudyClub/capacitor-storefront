package health.hsc.plugins.storefront;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.getcapacitor.JSObject;
import java.util.Locale;

/** The storefront as it is handed to JavaScript. */
public final class StorefrontInfo {

    public static final String SOURCE = "playBilling";

    private final String countryCode;
    private final String countryCode3;

    /**
     * @param countryCode ISO 3166-1 alpha-2 country code, upper case.
     * @param countryCode3 ISO 3166-1 alpha-3 country code, upper case, or {@code null} when unknown.
     */
    public StorefrontInfo(@NonNull String countryCode, @Nullable String countryCode3) {
        this.countryCode = countryCode;
        this.countryCode3 = countryCode3;
    }

    /** Builds the info from the alpha-2 code Google Play reports. */
    @NonNull
    public static StorefrontInfo fromPlayCountryCode(@NonNull String playCountryCode) {
        String alpha2 = playCountryCode.trim().toUpperCase(Locale.ROOT);
        return new StorefrontInfo(alpha2, CountryCodes.alpha3(alpha2));
    }

    /** ISO 3166-1 alpha-2 country code, upper case. */
    @NonNull
    public String getCountryCode() {
        return countryCode;
    }

    /** ISO 3166-1 alpha-3 country code, upper case, or {@code null} when unknown. */
    @Nullable
    public String getCountryCode3() {
        return countryCode3;
    }

    /** The JSON payload resolved to the plugin call. */
    @NonNull
    public JSObject toJSObject() {
        JSObject json = new JSObject();
        json.put("countryCode", countryCode);
        if (countryCode3 != null) {
            json.put("countryCode3", countryCode3);
        }
        json.put("source", SOURCE);
        return json;
    }

    @Override
    public String toString() {
        return "StorefrontInfo{countryCode=" + countryCode + ", countryCode3=" + countryCode3 + "}";
    }
}
