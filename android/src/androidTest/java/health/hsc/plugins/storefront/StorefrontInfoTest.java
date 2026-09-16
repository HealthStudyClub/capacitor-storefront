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

    private static final String PLAY_STORE = "com.android.vending";

    @Test
    public void buildsInfoFromPlayCountryCode() {
        StorefrontInfo info = StorefrontInfo.fromPlayCountryCode(" de ", PLAY_STORE);

        assertEquals("DE", info.getCountryCode());
        assertEquals("DEU", info.getCountryCode3());
        assertEquals(PLAY_STORE, info.getInstaller());
    }

    @Test
    public void unknownCountryHasNoAlpha3Code() {
        StorefrontInfo info = StorefrontInfo.fromPlayCountryCode("ZZ", null);

        assertEquals("ZZ", info.getCountryCode());
        assertNull(info.getCountryCode3());
        assertNull(info.getInstaller());
    }

    @Test
    public void jsonPayloadContainsAllFields() {
        JSObject json = StorefrontInfo.fromPlayCountryCode("US", PLAY_STORE).toJSObject();

        assertEquals("US", json.getString("countryCode"));
        assertEquals("USA", json.getString("countryCode3"));
        assertEquals("playBilling", json.getString("source"));
        assertEquals(PLAY_STORE, json.getString("installer"));
        assertEquals(4, json.length());
    }

    @Test
    public void jsonPayloadOmitsUnknownAlpha3Code() {
        JSObject json = new StorefrontInfo("ZZ", null, PLAY_STORE).toJSObject();

        assertEquals("ZZ", json.getString("countryCode"));
        assertFalse(json.has("countryCode3"));
        assertEquals(PLAY_STORE, json.getString("installer"));
        assertEquals(3, json.length());
    }

    @Test
    public void jsonPayloadOmitsUnknownInstaller() {
        JSObject json = StorefrontInfo.fromPlayCountryCode("US", null).toJSObject();

        assertEquals("US", json.getString("countryCode"));
        assertEquals("USA", json.getString("countryCode3"));
        assertEquals("playBilling", json.getString("source"));
        assertFalse(json.has("installer"));
        assertEquals(3, json.length());
    }

    @Test
    public void billingErrorCarriesResponseCodeDebugMessageAndInstaller() {
        BillingResult result = BillingResult.newBuilder()
            .setResponseCode(BillingClient.BillingResponseCode.BILLING_UNAVAILABLE)
            .setDebugMessage("no account")
            .build();

        StorefrontException error = StorefrontException.unavailable("Google Play Billing is not available", result, PLAY_STORE);

        assertEquals(StorefrontException.CODE_UNAVAILABLE, error.getCode());
        assertEquals(Integer.valueOf(3), error.getResponseCode());
        assertEquals("no account", error.getDebugMessage());
        assertEquals(PLAY_STORE, error.getInstaller());
        assertTrue(error.getMessage(), error.getMessage().contains("response code 3"));
        assertTrue(error.getMessage(), error.getMessage().contains("no account"));
        JSObject data = error.toData();
        assertEquals(3, data.getInteger("responseCode").intValue());
        assertEquals("no account", data.getString("debugMessage"));
        assertEquals(PLAY_STORE, data.getString("installer"));
        assertEquals(3, data.length());
    }

    @Test
    public void billingErrorWithoutInstallerOmitsIt() {
        BillingResult result = BillingResult.newBuilder().setResponseCode(BillingClient.BillingResponseCode.BILLING_UNAVAILABLE).build();

        StorefrontException error = StorefrontException.unavailable("Google Play Billing is not available", result, null);

        assertNull(error.getInstaller());
        JSObject data = error.toData();
        assertEquals(3, data.getInteger("responseCode").intValue());
        assertFalse(data.has("debugMessage"));
        assertFalse(data.has("installer"));
        assertEquals(1, data.length());
    }

    @Test
    public void unavailableErrorWithoutBillingResultCarriesOnlyTheInstaller() {
        StorefrontException error = StorefrontException.unavailable("disconnected", "com.amazon.venezia");

        assertEquals(StorefrontException.CODE_UNAVAILABLE, error.getCode());
        assertNull(error.getResponseCode());
        assertNull(error.getDebugMessage());
        JSObject data = error.toData();
        assertEquals("com.amazon.venezia", data.getString("installer"));
        assertEquals(1, data.length());
    }

    @Test
    public void timeoutErrorWithoutInstallerHasNoData() {
        StorefrontException error = StorefrontException.timeout(1500, null);

        assertEquals(StorefrontException.CODE_TIMEOUT, error.getCode());
        assertTrue(error.getMessage(), error.getMessage().contains("1500 ms"));
        assertNull(error.toData());
    }

    @Test
    public void timeoutErrorCarriesTheInstaller() {
        StorefrontException error = StorefrontException.timeout(1500, PLAY_STORE);

        assertEquals(StorefrontException.CODE_TIMEOUT, error.getCode());
        assertEquals(PLAY_STORE, error.getInstaller());
        JSObject data = error.toData();
        assertEquals(PLAY_STORE, data.getString("installer"));
        assertEquals(1, data.length());
    }
}
