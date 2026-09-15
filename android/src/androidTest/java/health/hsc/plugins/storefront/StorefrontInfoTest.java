package health.hsc.plugins.storefront;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingResult;
import com.getcapacitor.JSObject;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class StorefrontInfoTest {

    @Test
    public void buildsInfoFromPlayCountryCode() {
        StorefrontInfo info = StorefrontInfo.fromPlayCountryCode(" de ");

        assertEquals("DE", info.getCountryCode());
        assertEquals("DEU", info.getCountryCode3());
    }

    @Test
    public void unknownCountryHasNoAlpha3Code() {
        StorefrontInfo info = StorefrontInfo.fromPlayCountryCode("ZZ");

        assertEquals("ZZ", info.getCountryCode());
        assertNull(info.getCountryCode3());
    }

    @Test
    public void jsonPayloadContainsAllFields() {
        JSObject json = StorefrontInfo.fromPlayCountryCode("US").toJSObject();

        assertEquals("US", json.getString("countryCode"));
        assertEquals("USA", json.getString("countryCode3"));
        assertEquals("playBilling", json.getString("source"));
        assertEquals(3, json.length());
    }

    @Test
    public void jsonPayloadOmitsUnknownAlpha3Code() {
        JSObject json = new StorefrontInfo("ZZ", null).toJSObject();

        assertEquals("ZZ", json.getString("countryCode"));
        assertFalse(json.has("countryCode3"));
        assertEquals(2, json.length());
    }

    @Test
    public void billingErrorCarriesResponseCodeAndDebugMessage() {
        BillingResult result = BillingResult.newBuilder()
            .setResponseCode(BillingClient.BillingResponseCode.BILLING_UNAVAILABLE)
            .setDebugMessage("no account")
            .build();

        StorefrontException error = StorefrontException.unavailable("Google Play Billing is not available", result);

        assertEquals(StorefrontException.CODE_UNAVAILABLE, error.getCode());
        assertEquals(Integer.valueOf(3), error.getResponseCode());
        assertEquals("no account", error.getDebugMessage());
        assertTrue(error.getMessage(), error.getMessage().contains("response code 3"));
        assertTrue(error.getMessage(), error.getMessage().contains("no account"));
        JSObject data = error.toData();
        assertEquals(3, data.getInteger("responseCode").intValue());
        assertEquals("no account", data.getString("debugMessage"));
    }

    @Test
    public void timeoutErrorHasNoData() {
        StorefrontException error = StorefrontException.timeout(1500);

        assertEquals(StorefrontException.CODE_TIMEOUT, error.getCode());
        assertTrue(error.getMessage(), error.getMessage().contains("1500 ms"));
        assertNull(error.toData());
    }
}
