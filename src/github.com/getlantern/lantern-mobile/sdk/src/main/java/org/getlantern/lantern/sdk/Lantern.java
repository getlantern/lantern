package org.getlantern.lantern.sdk;

import android.content.Context;
import android.util.Log;
import android.webkit.WebView;

import java.net.InetAddress;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.io.File;
import java.util.Map;
import java.util.HashMap;


import go.client.*;
import org.getlantern.lantern.sdk.Utils;

public class Lantern extends Client.Provider.Stub {

    private static final String TAG = "Lantern";
    private final static String settingsFile = "settings.yaml";
    private final static String DEFAULT_DNS_SERVER = "8.8.4.4";
    private final String device = android.os.Build.DEVICE;
    private final String model = android.os.Build.MODEL;
    private final String version = "" + android.os.Build.VERSION.SDK_INT + " ("  + android.os.Build.VERSION.RELEASE + ")";
    private final Analytics analytics;

    private Context context;
    private String settingsDir;
    private String appName = "Lantern";
    private String proxyHost = "127.0.0.1";
    private int proxyPort = 8787;
    private Map settings = new HashMap();
    private boolean vpnMode = false;

    private Thread mThread;

    public Lantern() {
        this.analytics = new Analytics(null);
    }

    public Lantern(Context context, String settingsDir) {
        this(context, settingsDir, false);
    }

    public Lantern(Context context, String settingsDir, boolean vpnMode) {
        this.context = context;
        this.settingsDir = settingsDir;
        this.vpnMode = vpnMode;
        this.analytics = new Analytics(context);
    }

    public Map getSettings() {
        return settings;
    }

    // loadSettings loads the settings.yaml file into a map
    // and copies it over to the app's internal storage directory
    // for easy access from the backend
    public Map loadSettings() {
        try {
            settings = Utils.loadSettings(settingsDir, settingsFile);
            if (settings != null) {
                appName = (String)settings.get("appname");
                Log.d(TAG, "App running Lantern is " + appName);
            }
            Client.Configure(this);

        } catch (Exception e) {
            Log.d(TAG, "Unable to load settings file: " + e.getMessage());
        }
        return settings;
    }

    public void Start() {
        final Lantern lantern = this;
        try {
            Log.d(TAG, "About to start Lantern..");
            lantern.loadSettings();
            Client.Start(lantern);
        } catch (final Exception e) {
            Log.e(TAG, "Fatal error while trying to run Lantern: " + e);
        }
    }

    public void stop() {
        Log.d(TAG, "About to stop Lantern..");
        try {
            Client.Stop();
            if (mThread != null) {
                mThread.interrupt();
            }
        } catch (final Exception e) {

        }
    }

    @Override
    public String GetDnsServer() {
        return DEFAULT_DNS_SERVER;
    }


    @Override
    public void AfterStart(String latestVersion, String host, String port) {
        Log.d(TAG, "Lantern successfully started; running version: " + latestVersion);

        this.proxyHost = host;
        this.proxyPort = Integer.parseInt(port);

        if (!VpnMode()) {
            System.setProperty("http.proxyHost", host);
            System.setProperty("http.proxyPort", port);
            System.setProperty("https.proxyHost", host);
            System.setProperty("https.proxyPort", port);
        }

        analytics.sendNewSessionEvent();
    }

    public void SetWebViewProxy(WebView webView) {
        Log.d(TAG, "Updating webview proxy settings");
        // ProxySettings.setProxy(context, webView, proxyHost, proxyPort);
    }

    @Override
    public String Model() {
        return this.model;
    }

    @Override
    public String Device() {
        return this.device;
    }

    @Override
    public String Version() {
        return this.version;
    }

    @Override
    public String AppName() {
        return this.appName;
    }

    @Override
    public boolean VpnMode() {
        return vpnMode;
    }

    // LoadSettingsDir gets the path to the app's internal storage directory
    @Override
    public String SettingsDir() {
        return settingsDir;
    }

    // Notice is used to signal messages from Lantern
    // if fatal is true, Lantern encountered a fatal error
    // and we should shutdown
    @Override
    public void Notice(String message, boolean fatal) {

    }

    @Override
    public void Protect(long fileDescriptor) throws Exception {

    }
}
