package health.hsc.plugins.storefront;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class CountryCodesTest {

    @Test
    public void mapsCommonStorefronts() {
        assertEquals("USA", CountryCodes.alpha3("US"));
        assertEquals("DEU", CountryCodes.alpha3("DE"));
        assertEquals("GBR", CountryCodes.alpha3("GB"));
        assertEquals("CHE", CountryCodes.alpha3("CH"));
        assertEquals("AUT", CountryCodes.alpha3("AT"));
        assertEquals("JPN", CountryCodes.alpha3("JP"));
    }

    @Test
    public void lookupIsCaseAndWhitespaceInsensitive() {
        assertEquals("DEU", CountryCodes.alpha3("de"));
        assertEquals("USA", CountryCodes.alpha3(" us\n"));
    }

    @Test
    public void unknownCodesReturnNull() {
        assertNull(CountryCodes.alpha3(null));
        assertNull(CountryCodes.alpha3(""));
        assertNull(CountryCodes.alpha3("DEU"));
        assertNull(CountryCodes.alpha3("ZZ"));
        assertNull(CountryCodes.alpha3("1!"));
    }
}
