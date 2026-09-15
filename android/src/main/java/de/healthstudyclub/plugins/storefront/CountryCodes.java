package de.healthstudyclub.plugins.storefront;

import androidx.annotation.Nullable;
import java.util.IllformedLocaleException;
import java.util.Locale;
import java.util.MissingResourceException;

/** ISO 3166-1 country code conversion backed by the platform's locale data. */
final class CountryCodes {

    private CountryCodes() {}

    /**
     * Returns the ISO 3166-1 alpha-3 code for an alpha-2 code, or {@code null} when the code is
     * unknown. The lookup is case insensitive.
     */
    @Nullable
    static String alpha3(@Nullable String alpha2) {
        if (alpha2 == null) {
            return null;
        }
        String region = alpha2.trim().toUpperCase(Locale.ROOT);
        if (region.length() != 2) {
            return null;
        }
        try {
            String alpha3 = new Locale.Builder().setRegion(region).build().getISO3Country();
            return alpha3 == null || alpha3.isEmpty() ? null : alpha3.toUpperCase(Locale.ROOT);
        } catch (IllformedLocaleException | MissingResourceException e) {
            return null;
        }
    }
}
