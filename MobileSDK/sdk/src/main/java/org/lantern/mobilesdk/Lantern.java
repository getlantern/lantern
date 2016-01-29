package org.lantern.mobilesdk;

/**
 * Created by ox.to.a.cart on 1/28/16.
 */
public class Lantern {
    public static void start(String configDir, int timeoutMillis) {
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

    public static void stop() {
        System.clearProperty("http.proxyHost");
        System.clearProperty("http.proxyPort");
        System.clearProperty("https.proxyHost");
        System.clearProperty("https.proxyPort");
    }
}
