package org.lantern.mobilesdk;

import android.content.Context;

import com.google.android.gms.analytics.GoogleAnalytics;
import com.google.android.gms.analytics.HitBuilders;
import com.google.android.gms.analytics.Tracker;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

/**
 * API for embedding the Lantern proxy
 */
public abstract class Lantern {
    private static final Map<String, Tracker> trackersById = new HashMap<>();
    private static boolean enabled = false;

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
     * @param updateProxySettings    whether or not to update the application proxy settings
     * @param analyticsTrackingId (optional tracking ID for tracking Google analytics)
     * @return the {@link go.lantern.Lantern.StartResult} with port information about the started
     * lantern
     */
    public static StartResult enable(Context context, int timeoutMillis, boolean updateProxySettings,
            String analyticsTrackingId)
            throws LanternNotRunningException {
        return doEnable(context, timeoutMillis, analyticsTrackingId, updateProxySettings,
                "org.lantern.mobilesdk.embedded.EmbeddedLantern");
    }

    /**
     * Like {@link #enable(Context, int, String)} but runs the proxy in a Service.
     *
     * @param context
     * @param timeoutMillis
     * @param updateProxySettings
     * @param analyticsTrackingId
     * @return
     * @throws LanternNotRunningException
     */
    public static StartResult enableAsService(Context context, int timeoutMillis, boolean updateProxySettings, 
            String analyticsTrackingId)
            throws LanternNotRunningException {
        return doEnable(context, timeoutMillis, analyticsTrackingId, updateProxySettings, 
                "org.lantern.mobilesdk.LanternServiceManager");
    }

    private synchronized static StartResult doEnable(Context context, int timeoutMillis,
            String analyticsTrackingId, boolean updateProxySettings, String implClassName)
            throws LanternNotRunningException {
        Lantern lantern = instanceOf(implClassName);
        StartResult result = lantern.start(context, timeoutMillis);
        if (updateProxySettings) {
            proxyOn(result.getHTTPAddr());
        }
        if (analyticsTrackingId != null && !enabled) {
            trackStartSession(context, analyticsTrackingId);
        }
        enabled = true;
        return result;
    }

    /**
     * Note - we use dynamic class loading to avoid loading unused classes into the caller's
     * classloader (i.e. to avoid loading native dependencies when running as service). This is
     * important because in some situations, it appears that including the Lantern native library
     * inside the same process as an application can cause instability on some phones (e.g. Samsung
     * Galaxy S4).
     *
     * @param implClassName
     * @return
     * @throws LanternNotRunningException
     */
    private static Lantern instanceOf(String implClassName) throws LanternNotRunningException {
        try {
            Class<? extends Lantern> implClass = (Class<? extends Lantern>) Lantern.class.getClassLoader().loadClass(implClassName);
            return implClass.newInstance();
        } catch (Exception e) {
            throw new LanternNotRunningException("Unable to get implementation class: " + e.getMessage(), e);
        }
    }

    protected abstract StartResult start(Context context, int timeoutMillis) throws LanternNotRunningException;

    private static void proxyOn(String addr) {
        int lastIndexOfColon = addr.lastIndexOf(':');
        String host = addr.substring(0, lastIndexOfColon);
        String port = addr.substring(lastIndexOfColon + 1);
        System.setProperty("http.proxyHost", host);
        System.setProperty("http.proxyPort", port);
        System.setProperty("https.proxyHost", host);
        System.setProperty("https.proxyPort", port);
    }

    /**
     * Disables the Lantern proxy so that connections within this process will no longer be proxied.
     * This leaves any background activity for the proxy running, and subsequent calls to
     * {@link #enable(Context, int, String)} will reuse the existing proxy in this process.
     */
    public synchronized static void disable(Context context) {
        System.clearProperty("http.proxyHost");
        System.clearProperty("http.proxyPort");
        System.clearProperty("https.proxyHost");
        System.clearProperty("https.proxyPort");
        // TODO: stop service if necessary
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

    public synchronized static Tracker trackerFor(Context context, String trackingId) {
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

    public static String configDirFor(Context context, String suffix) {
        return new File(context.getFilesDir().getAbsolutePath(), ".lantern" + suffix).getAbsolutePath();
    }
}
