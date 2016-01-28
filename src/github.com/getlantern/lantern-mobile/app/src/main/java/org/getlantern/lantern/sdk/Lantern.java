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

import com.google.common.net.HostAndPort;

public class Lantern extends Client.Provider.Stub {

    private static final String TAG = "Lantern";
    private final static String settingsFile = "settings.yaml";
    private final static String DEFAULT_DNS_SERVER = "8.8.4.4";
    private final String device = android.os.Build.DEVICE;
    private final String model = android.os.Build.MODEL;
    private final String version = "" + android.os.Build.VERSION.SDK_INT + " ("  + android.os.Build.VERSION.RELEASE + ")";
    private final Analytics analytics;

    private Context context;
    private String settingsDir = "";
    private String appName = "Lantern";
    private String proxyHost = "127.0.0.1";
    private int proxyPort = 8787;
    private Map settings = new HashMap();
    private boolean vpnMode = false;

    private Thread mThread;

    public Lantern(Context context, String settingsDir) {
        this(context, settingsDir, false);
    }

    public Lantern(Context context, String settingsDir, boolean vpnMode) {
        this.context = context;
        this.vpnMode = vpnMode;
        this.analytics = new Analytics(context);
        this.settingsDir = settingsDir;

        // if no settings dir specified,
        // attempt to derive one from the 
        // application context
        if (context != null && settingsDir.equals("")) {
            File f = context.getFilesDir();
            String path = "";
            if (f != null) {
                path = f.getPath();
            }
            this.settingsDir = path;
        }
    }

    public Map getSettings() {
        return settings;
    }

    // loadSettings loads the settings.yaml file into a map
    // and copies it over to the app's internal storage directory
    // for easy access from the backend
    public Map loadSettings() {
        try {
            settings = Utils.loadSettings(context, settingsFile);
            if (settings.get("httpaddr") != null) {
                String httpAddr = (String)settings.get("httpaddr");
                if (httpAddr != null) {
                    HostAndPort hp = HostAndPort.fromString(httpAddr);
                    this.proxyHost = hp.getHostText();
                    this.proxyPort = hp.getPort();
                }
            }
            Client.Configure(this);
        } catch (Exception e) {
            Log.d(TAG, "Unable to load settings file: " + e.getMessage());
        }
        return settings;
    }

    public void Start() {
        final Lantern lantern = this;
        Log.d(TAG, "About to start Lantern..");
        mThread = new Thread() {
            public void run() {
                try {
                    lantern.loadSettings();
                    Client.Start(lantern);
                } catch (final Exception e) {
                    Log.e(TAG, "Fatal error while trying to run Lantern: " + e.getMessage());
                    e.printStackTrace();
                }
            }
        };
        mThread.start();
    }

    public void Stop() {
        Log.d(TAG, "About to stop Lantern..");
        try {
            Client.Stop();
            if (mThread != null) {
                mThread.interrupt();
            }
        } catch (final Exception e) {
            Log.e(TAG, "Fatal error while trying to stop Lantern: " + e);
        }
    }

    @Override
    public String GetDnsServer() {
        return DEFAULT_DNS_SERVER;
    }


    @Override
    public void AfterStart(String latestVersion) {
        Log.d(TAG, "Lantern successfully started; running version: " + latestVersion);

        if (!VpnMode()) {
            System.setProperty("http.proxyHost", this.proxyHost);
            System.setProperty("http.proxyPort",  this.proxyPort + "");
            System.setProperty("https.proxyHost", this.proxyHost);
            System.setProperty("https.proxyPort", this.proxyPort + "");
        }

        analytics.sendNewSessionEvent();
    }

    public void SetWebViewProxy(WebView webView) {
        Log.d(TAG, "Updating webview proxy settings");
        ProxySettings.setProxy(context, webView, 
                this.proxyHost, this.proxyPort);
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
