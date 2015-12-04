package org.getlantern.lantern.sdk;

import android.content.Context;
import android.util.Log;

import java.net.InetAddress;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.io.File;
import java.util.Map;
import java.util.HashMap;
 

import go.client.*;
import org.getlantern.lantern.sdk.Analytics;
import org.getlantern.lantern.sdk.Utils;

public class Lantern extends Client.Provider.Stub {

    private static final String TAG = "Lantern";
    private final static String settingsFile = "settings.yaml";
    private final static String DEFAULT_DNS_SERVER = "8.8.4.4";
    private final String device = android.os.Build.DEVICE;
    private final String model = android.os.Build.MODEL;
    private final String version = "" + android.os.Build.VERSION.SDK_INT + " ("  + android.os.Build.VERSION.RELEASE + ")";
    final private Analytics analytics;
    private Context context;
    private String appName = "Lantern";
    private Map settings = new HashMap();
    private boolean vpnMode = false;

    public Lantern() {
        this.analytics = new Analytics(null);
    }

    public Lantern(Context context, boolean vpnMode) {
        this.context = context;
        this.vpnMode = vpnMode;
        this.analytics = new Analytics(this.context);
        this.loadSettings();
    }

    public Map getSettings() {
        return settings;
    }

    // loadSettings loads the settings.yaml file into a map
    // and copies it over to the app's internal storage directory
    // for easy access from the backend
    public Map loadSettings() {
        try {
            settings = Utils.loadSettings(this.context, settingsFile);
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

    public void start() {
        try {
            Log.d(TAG, "About to start Lantern..");
            Client.Start(this);

        } catch (final Exception e) {
            Log.e(TAG, "Fatal error while trying to run Lantern: " + e);
            throw new RuntimeException(e);
        }
    }

    public void stop() {
        Log.d(TAG, "About to stop Lantern..");
        try {
            Client.Stop();
        } catch(final Exception e) {
            Log.e(TAG, "Error while trying to stop Lantern: " + e);
        }
    }

    @Override
    public String GetDnsServer() {
        return DEFAULT_DNS_SERVER;
    }


    @Override
    public void AfterStart(String latestVersion) {
        Log.d(TAG, "Lantern successfully started; running version: " + latestVersion);
        analytics.sendNewSessionEvent();
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
        File f = this.context.getFilesDir();
        String path = "";
        if (f != null) {
            path = f.getPath();
            Log.d(TAG, "Got user settings dir: " + path);
        }
        return path;
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
