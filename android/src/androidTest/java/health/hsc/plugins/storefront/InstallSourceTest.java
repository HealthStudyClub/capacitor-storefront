package health.hsc.plugins.storefront;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.util.Log;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class InstallSourceTest {

    private static final String TAG = "StorefrontTest";

    /** A Java/Android package name: dot separated identifiers. */
    private static final String PACKAGE_NAME = "[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)+";

    private static Context context() {
        return InstrumentationRegistry.getInstrumentation().getTargetContext();
    }

    @Test
    public void reportsNullOrAPackageNameForTheTestApp() {
        String installer = InstallSource.installer(context());

        Log.i(TAG, "Installer package of " + context().getPackageName() + ": " + installer);
        if (installer != null) {
            assertTrue("not a package name: " + installer, installer.matches(PACKAGE_NAME));
        }
    }

    @Test
    public void isStableAcrossCalls() {
        assertEquals(InstallSource.installer(context()), InstallSource.installer(context()));
    }

    @Test
    public void unknownPackageYieldsNull() {
        assertNull(InstallSource.installer(context().getPackageManager(), "health.hsc.plugins.storefront.does.not.exist"));
    }
}
