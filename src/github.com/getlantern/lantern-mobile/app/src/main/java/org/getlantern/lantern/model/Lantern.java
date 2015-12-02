package org.getlantern.lantern.model;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
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
import org.getlantern.lantern.activity.UpdaterActivity;
import org.getlantern.lantern.model.Analytics;
import org.getlantern.lantern.model.Utils;
import org.getlantern.lantern.service.LanternVpn;

public class Lantern extends Client.Provider.Stub {

    private static final String TAG = "Lantern";
    private LanternVpn service;
    final private Analytics analytics;

    private Context context;
    private String appName = "Lantern";
    private final String device = android.os.Build.DEVICE;
    private final String model = android.os.Build.MODEL;
    private final String version = "" + android.os.Build.VERSION.SDK_INT + " ("  + android.os.Build.VERSION.RELEASE + ")";


    private final static String settingsFile = "settings.yaml";

    private Map settings = new HashMap();

    private boolean vpnMode = false;

    private final static String DEFAULT_DNS_SERVER = "8.8.4.4";

    public Lantern(LanternVpn service) {
        this.service = service;
        this.context = service.getApplicationContext();
        this.vpnMode = true;
        this.analytics = new Analytics(this.context);
        this.loadSettings();
    }

    public Lantern(Context context) {
        this.context = context;
        this.vpnMode = false;
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

    public void setVpnMode(boolean vpnMode) {
        this.vpnMode = vpnMode;
    }

    @Override
    public String GetDnsServer() {
        try {
            return service.getDnsResolver(service);
        } catch (Exception e) {
            return DEFAULT_DNS_SERVER;
        }
    }


    @Override
    public void AfterStart(String latestVersion) {
        Log.d(TAG, "Lantern successfully started; running version: " + latestVersion);
        service.setVersionNum(latestVersion);
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
        return this.vpnMode;
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
        Log.d(TAG, "Received a new message from Lantern: " + message);
        if (fatal) {
            Log.d(TAG, "Received fatal error.. Shutting down.");
            try { 
                // if we receive a fatal notice from Lantern
                // then we shut down the VPN interface
                // and close Tun2Socks
                this.service.stop();
                this.service.UI.handleFatalError();

            } catch (Exception e) {

            }
        }
    }

    // Protect is used to exclude a socket specified by fileDescriptor
    // from the VPN connection. Once protected, the underlying connection
    // is bound to the VPN device and won't be forwarded
    @Override
    public void Protect(long fileDescriptor) throws Exception {
        if (!this.service.protect((int) fileDescriptor)) {
            throw new Exception("protect socket failed");
        }
    }
}
