package de.healthstudyclub.plugins.storefront;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import com.getcapacitor.JSObject;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.Test;
import org.junit.runner.RunWith;

/** Exercises the plugin's bridge layer with a fake storefront provider. */
@RunWith(AndroidJUnit4.class)
public class StorefrontPluginTest {

    private static final long WAIT_MS = 2_000;

    @Test
    public void resolvesWithTheProvidersStorefront() throws Exception {
        StorefrontPlugin plugin = new StorefrontPlugin();
        plugin.setStorefrontProvider((timeoutMs, callback) -> callback.onSuccess(StorefrontInfo.fromPlayCountryCode("de")));
        RecordingPluginCall call = new RecordingPluginCall(new JSObject());

        plugin.getStorefront(call);

        assertTrue("call did not settle", call.awaitSettled(WAIT_MS));
        assertTrue(call.isResolved());
        assertFalse(call.isRejected());
        assertNotNull(call.resolvedData);
        assertEquals("DE", call.resolvedData.getString("countryCode"));
        assertEquals("DEU", call.resolvedData.getString("countryCode3"));
        assertEquals("playBilling", call.resolvedData.getString("source"));
        assertEquals(1, call.settleCount());
    }

    @Test
    public void rejectsWithTheProvidersError() throws Exception {
        StorefrontException error = new StorefrontException(StorefrontException.CODE_UNAVAILABLE, "no play", 3, "BILLING_UNAVAILABLE");
        StorefrontPlugin plugin = new StorefrontPlugin();
        plugin.setStorefrontProvider((timeoutMs, callback) -> callback.onError(error));
        RecordingPluginCall call = new RecordingPluginCall(new JSObject());

        plugin.getStorefront(call);

        assertTrue("call did not settle", call.awaitSettled(WAIT_MS));
        assertTrue(call.isRejected());
        assertFalse(call.isResolved());
        assertEquals("UNAVAILABLE", call.rejectCode);
        assertEquals("no play", call.rejectMessage);
        assertSame(error, call.rejectException);
        assertNotNull(call.rejectData);
        assertEquals(3, call.rejectData.getInteger("responseCode").intValue());
        assertEquals("BILLING_UNAVAILABLE", call.rejectData.getString("debugMessage"));
    }

    @Test
    public void rejectsTimeoutWithoutData() throws Exception {
        StorefrontPlugin plugin = new StorefrontPlugin();
        plugin.setStorefrontProvider((timeoutMs, callback) -> callback.onError(StorefrontException.timeout(timeoutMs)));
        RecordingPluginCall call = new RecordingPluginCall(new JSObject());

        plugin.getStorefront(call);

        assertTrue("call did not settle", call.awaitSettled(WAIT_MS));
        assertEquals("TIMEOUT", call.rejectCode);
        assertNull(call.rejectData);
    }

    @Test
    public void passesTimeoutOptionToTheProvider() throws Exception {
        AtomicLong seenTimeout = new AtomicLong(-1);
        StorefrontPlugin plugin = new StorefrontPlugin();
        plugin.setStorefrontProvider((timeoutMs, callback) -> {
            seenTimeout.set(timeoutMs);
            callback.onSuccess(StorefrontInfo.fromPlayCountryCode("US"));
        });
        JSObject options = new JSObject();
        options.put("timeout", 1234);
        RecordingPluginCall call = new RecordingPluginCall(options);

        plugin.getStorefront(call);

        assertTrue("call did not settle", call.awaitSettled(WAIT_MS));
        assertEquals(1234L, seenTimeout.get());
    }

    @Test
    public void usesDefaultTimeoutWhenOptionIsMissingOrInvalid() {
        assertEquals(StorefrontPlugin.DEFAULT_TIMEOUT_MS, StorefrontPlugin.timeout(null));
        assertEquals(StorefrontPlugin.DEFAULT_TIMEOUT_MS, StorefrontPlugin.timeout(0d));
        assertEquals(StorefrontPlugin.DEFAULT_TIMEOUT_MS, StorefrontPlugin.timeout(-5d));
        assertEquals(StorefrontPlugin.DEFAULT_TIMEOUT_MS, StorefrontPlugin.timeout(Double.NaN));
        assertEquals(StorefrontPlugin.DEFAULT_TIMEOUT_MS, StorefrontPlugin.timeout(Double.POSITIVE_INFINITY));
        assertEquals(2500L, StorefrontPlugin.timeout(2500d));
        assertEquals(1L, StorefrontPlugin.timeout(0.4d));
    }
}
