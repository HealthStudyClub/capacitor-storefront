package de.healthstudyclub.plugins.storefront;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import java.util.Arrays;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.Test;
import org.junit.runner.RunWith;

/**
 * Goes through the real Play Billing Library on the emulator or device.
 *
 * <p>Whether Google Play answers depends on the device: an emulator without the Play Store (or
 * without a signed in Google account) cannot report a storefront. The contract the plugin has to
 * keep in every environment is that the lookup settles exactly once, within the timeout, with
 * either a well formed storefront or a well formed error.
 */
@RunWith(AndroidJUnit4.class)
public class PlayBillingStorefrontProviderTest {

    private static final String TAG = "StorefrontTest";

    private static final class Outcome implements StorefrontProvider.Callback {

        final CountDownLatch settled = new CountDownLatch(1);
        final AtomicInteger callbacks = new AtomicInteger();
        final AtomicReference<StorefrontInfo> info = new AtomicReference<>();
        final AtomicReference<StorefrontException> error = new AtomicReference<>();

        @Override
        public void onSuccess(@NonNull StorefrontInfo result) {
            callbacks.incrementAndGet();
            info.set(result);
            settled.countDown();
        }

        @Override
        public void onError(@NonNull StorefrontException failure) {
            callbacks.incrementAndGet();
            error.set(failure);
            settled.countDown();
        }
    }

    private static Context context() {
        return InstrumentationRegistry.getInstrumentation().getTargetContext();
    }

    @Test
    public void settlesWithStorefrontOrWellFormedError() throws Exception {
        PlayBillingStorefrontProvider provider = new PlayBillingStorefrontProvider(context());
        Outcome outcome = new Outcome();

        provider.getStorefront(15_000, outcome);

        assertTrue("lookup did not settle within 20 s", outcome.settled.await(20, TimeUnit.SECONDS));
        StorefrontInfo info = outcome.info.get();
        StorefrontException error = outcome.error.get();
        if (info != null) {
            Log.i(TAG, "Google Play reported storefront " + info);
            assertNull(error);
            assertTrue("countryCode must be ISO 3166-1 alpha-2: " + info.getCountryCode(), info.getCountryCode().matches("[A-Z]{2}"));
            assertNotNull("countryCode3 must be derivable for a real storefront", info.getCountryCode3());
            assertTrue(info.getCountryCode3().matches("[A-Z]{3}"));
        } else {
            assertNotNull("neither storefront nor error reported", error);
            Log.i(TAG, "Google Play Billing unavailable on this device: " + error.getMessage());
            assertTrue(
                "unexpected error code " + error.getCode(),
                Arrays.asList(StorefrontException.CODE_UNAVAILABLE, StorefrontException.CODE_TIMEOUT).contains(error.getCode())
            );
            assertNotNull(error.getMessage());
        }
        Thread.sleep(500);
        assertEquals("the lookup must settle exactly once", 1, outcome.callbacks.get());
    }

    @Test
    public void veryShortTimeoutSettlesOnceWithTimeoutOrImmediateAnswer() throws Exception {
        PlayBillingStorefrontProvider provider = new PlayBillingStorefrontProvider(context());
        Outcome outcome = new Outcome();

        provider.getStorefront(1, outcome);

        assertTrue("lookup did not settle within 5 s", outcome.settled.await(5, TimeUnit.SECONDS));
        StorefrontException error = outcome.error.get();
        if (error != null) {
            assertTrue(
                "unexpected error code " + error.getCode(),
                Arrays.asList(StorefrontException.CODE_UNAVAILABLE, StorefrontException.CODE_TIMEOUT).contains(error.getCode())
            );
        } else {
            assertNotNull(outcome.info.get());
        }
        Thread.sleep(500);
        assertEquals("the lookup must settle exactly once", 1, outcome.callbacks.get());
    }

    @Test
    public void concurrentLookupsSettleIndependently() throws Exception {
        PlayBillingStorefrontProvider provider = new PlayBillingStorefrontProvider(context());
        Outcome first = new Outcome();
        Outcome second = new Outcome();

        provider.getStorefront(15_000, first);
        provider.getStorefront(15_000, second);

        assertTrue(first.settled.await(20, TimeUnit.SECONDS));
        assertTrue(second.settled.await(20, TimeUnit.SECONDS));
        Thread.sleep(500);
        assertEquals(1, first.callbacks.get());
        assertEquals(1, second.callbacks.get());
    }
}
