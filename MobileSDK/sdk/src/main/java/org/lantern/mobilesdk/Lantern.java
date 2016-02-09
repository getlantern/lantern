package org.lantern.mobilesdk;

import android.content.Context;

import com.google.android.gms.analytics.GoogleAnalytics;
import com.google.android.gms.analytics.HitBuilders;
import com.google.android.gms.analytics.Tracker;


import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Created by ox.to.a.cart on 1/28/16.
 */
public class Lantern {
    private static final Map<String, Tracker> trackersById = new HashMap<>();
    private static boolean enabled = false;

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
     * <p/>
     * <p>If a Lantern proxy is already running within this process, that proxy is reused.</p>
     * <p/>
     * <p>Note - this does not wait for the entire initialization sequence to finish, just for the
     * proxy to be listening. Once the proxy is listening, one can start to use it, even as it
     * finishes its initialization sequence. However, initial activity may be slow, so clients with
     * low read timeouts may time out.</p>
     *
     * @param context
     * @param timeoutMillis       how long to wait for proxy to start listening (should be fairly quick)
     * @param analyticsTrackingId (optional tracking ID for tracking Google analytics)
     * @return the {@link go.lantern.Lantern.StartResult} with port information about the started
     * lantern
     */
    public synchronized static go.lantern.Lantern.StartResult enable(Context context, int timeoutMillis, String analyticsTrackingId)
            throws LanternNotRunningException {
        String configDir = new File(context.getFilesDir().getAbsolutePath(), ".lantern").getAbsolutePath();
        go.lantern.Lantern.StartResult result = enable(configDir, timeoutMillis);
        if (analyticsTrackingId != null && !enabled) {
            trackStartSession(context, analyticsTrackingId);
        }
        return result;
    }

    private static go.lantern.Lantern.StartResult enable(String configDir, int timeoutMillis)
            throws LanternNotRunningException {
        try {
            go.lantern.Lantern.StartResult result = go.lantern.Lantern.Start(configDir, timeoutMillis);
            String addr = result.getHTTPAddr();
            int lastIndexOfColon = addr.lastIndexOf(':');
            String host = addr.substring(0, lastIndexOfColon);
            String port = addr.substring(lastIndexOfColon + 1);
            System.setProperty("http.proxyHost", host);
            System.setProperty("http.proxyPort", port);
            System.setProperty("https.proxyHost", host);
            System.setProperty("https.proxyPort", port);
            return result;
        } catch (Exception e) {
            throw new LanternNotRunningException("Unable to start Lantern: " + e.getMessage(), e);
        }
    }

    /**
     * Disables the Lantern proxy so that connections within this process will no longer be proxied.
     * This leaves any background activity for the proxy running, and subsequent calls to
     * {@link #enable(String, int)} will reuse the existing proxy in this process.
     */
    public synchronized static void disable() {
        System.clearProperty("http.proxyHost");
        System.clearProperty("http.proxyPort");
        System.clearProperty("https.proxyHost");
        System.clearProperty("https.proxyPort");
        enabled = false;
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

    private static void trackStartSession(Context context, String trackingId) {
        sendSessionEvent(context, trackingId, "Start");
    }

    private static void sendSessionEvent(Context context, String trackingId, String action) {
        trackerFor(context, trackingId).send(new HitBuilders.EventBuilder()
                .setCategory("Session")
                .setLabel("android")
                .setAction(action)
                .build());
    }

    private synchronized static Tracker trackerFor(Context context, String trackingId) {
        Tracker tracker = trackersById.get(trackingId);

        if (tracker == null) {
            GoogleAnalytics analytics = GoogleAnalytics.getInstance(context);
            analytics.setLocalDispatchPeriod(1800);

            tracker = analytics.newTracker(trackingId);
            tracker.enableAdvertisingIdCollection(true);
            tracker.enableAutoActivityTracking(true);
            tracker.enableExceptionReporting(true);
            tracker.setAnonymizeIp(true);

            trackersById.put(trackingId, tracker);
        }

        return tracker;
    }
}
