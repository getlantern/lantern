package org.lantern.mobilesdk;

import android.content.Context;

import java.io.File;

/**
 * Created by ox.to.a.cart on 1/28/16.
 */
public class Lantern {
    static {
        // Track extra info about Android for logging to Loggly.
        Lantern.addLoggingMetadata("androidDevice", android.os.Build.DEVICE);
        Lantern.addLoggingMetadata("androidModel", android.os.Build.MODEL);
        Lantern.addLoggingMetadata("androidSdkVersion", "" + android.os.Build.VERSION.SDK_INT + " (" + android.os.Build.VERSION.RELEASE + ")");
    }

    /**
     * <p>Starts Lantern at a random port, storing configuration information in the indicated
     * configDir and waiting up to timeoutMillis for the proxy to come online. If the proxy fails to
     * come online within the timeout, this throws an exception.</p>
     *
     * <p>If a Lantern proxy is already running within this process, that proxy is reused.</p>
     *
     * <p>Note - this does not wait for the entire initialization sequence to finish, just for the
     * proxy to be listening. Once the proxy is listening, one can start to use it, even as it
     * finishes its initialization sequence. However, initial activity may be slow, so clients with
     * low read timeouts may time out.</p>
     *
     * @param context
     * @param appName
     * @param timeoutMillis
     */
    public static void enable(Context context, String appName, int timeoutMillis) {
        String configDir = new File(context.getFilesDir().getAbsolutePath(), ".lantern_" + appName).getAbsolutePath();
        enable(configDir, timeoutMillis);
    }

    public static void enable(String configDir, int timeoutMillis) {
        try {
            String addr = go.lantern.Lantern.Start(configDir, timeoutMillis);
            String host = addr.split(":")[0];
            String port = addr.split(":")[1];
            System.setProperty("http.proxyHost", host);
            System.setProperty("http.proxyPort", port);
            System.setProperty("https.proxyHost", host);
            System.setProperty("https.proxyPort", port);
        } catch (Exception e) {
            throw new RuntimeException("Unable to start Lantern: " + e.getMessage(), e);
        }
    }

    /**
     * Disables the Lantern proxy so that connections within this process will no longer be proxied.
     * This leaves any background activity for the proxy running, and subsequent calls to
     * {@link #enable(String, int)} will reuse the existing proxy in this process.
     */
    public static void disable() {
        System.clearProperty("http.proxyHost");
        System.clearProperty("http.proxyPort");
        System.clearProperty("https.proxyHost");
        System.clearProperty("https.proxyPort");
    }

    /**
     * Adds metadata for reporting to cloud logging services.
     *
     * @param key
     * @param value
     */
    public static void addLoggingMetadata(String key, String value) {
        go.lantern.Lantern.AddLoggingMetadata(key, value);
    }
}
