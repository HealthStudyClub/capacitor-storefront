package health.hsc.plugins.storefront;

import android.content.Context;
import android.content.pm.InstallSourceInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/** Where the app was installed from, as recorded by Android's package manager. */
final class InstallSource {

    private InstallSource() {}

    /**
     * Returns the package name of the app that installed this app, e.g. {@code com.android.vending}
     * for Google Play, or {@code null} when the package manager did not record one (installs
     * through {@code adb} or from a file, or an installer that has since been removed).
     */
    @Nullable
    static String installer(@NonNull Context context) {
        return installer(context.getPackageManager(), context.getPackageName());
    }

    /** Same as {@link #installer(Context)} for an arbitrary installed package. */
    @Nullable
    static String installer(@NonNull PackageManager packageManager, @NonNull String packageName) {
        try {
            String installer;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                InstallSourceInfo source = packageManager.getInstallSourceInfo(packageName);
                installer = source.getInstallingPackageName();
            } else {
                installer = legacyInstaller(packageManager, packageName);
            }
            return installer == null || installer.trim().isEmpty() ? null : installer.trim();
        } catch (PackageManager.NameNotFoundException | IllegalArgumentException e) {
            // unknown package: NameNotFoundException on Android 11+, IllegalArgumentException before
            return null;
        }
    }

    @SuppressWarnings("deprecation")
    @Nullable
    private static String legacyInstaller(@NonNull PackageManager packageManager, @NonNull String packageName) {
        return packageManager.getInstallerPackageName(packageName);
    }
}
