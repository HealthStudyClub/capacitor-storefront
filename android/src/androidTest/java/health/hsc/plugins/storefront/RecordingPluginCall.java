package health.hsc.plugins.storefront;

import androidx.annotation.Nullable;
import com.getcapacitor.JSObject;
import com.getcapacitor.PluginCall;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * A {@link PluginCall} without a bridge: records what the plugin resolves or rejects instead of
 * sending it to the WebView. Every {@code reject} overload in Capacitor funnels into the
 * four-argument variant overridden here.
 */
final class RecordingPluginCall extends PluginCall {

    private final CountDownLatch settled = new CountDownLatch(1);
    private int settleCount = 0;

    @Nullable
    JSObject resolvedData;

    boolean resolvedEmpty;

    @Nullable
    String rejectMessage;

    @Nullable
    String rejectCode;

    @Nullable
    Exception rejectException;

    @Nullable
    JSObject rejectData;

    RecordingPluginCall(JSObject data) {
        super(null, "Storefront", "test-callback", "getStorefront", data);
    }

    @Override
    public void resolve(JSObject data) {
        resolvedData = data;
        settle();
    }

    @Override
    public void resolve() {
        resolvedEmpty = true;
        settle();
    }

    @Override
    public void reject(String msg, String code, Exception ex, JSObject data) {
        rejectMessage = msg;
        rejectCode = code;
        rejectException = ex;
        rejectData = data;
        settle();
    }

    private synchronized void settle() {
        settleCount++;
        settled.countDown();
    }

    boolean awaitSettled(long timeoutMs) throws InterruptedException {
        return settled.await(timeoutMs, TimeUnit.MILLISECONDS);
    }

    synchronized int settleCount() {
        return settleCount;
    }

    boolean isResolved() {
        return resolvedData != null || resolvedEmpty;
    }

    boolean isRejected() {
        return rejectCode != null || rejectMessage != null;
    }
}
