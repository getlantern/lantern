package org.getlantern.lantern.model;

import android.content.Context;
import android.content.Intent;
import android.util.Log;

import java.net.InetAddress;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.BlockingQueue;

import go.client.*;
import org.getlantern.lantern.activity.UpdaterActivity;
import org.getlantern.lantern.model.Analytics;
import org.getlantern.lantern.service.LanternVpn;
import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.model.VpnBuilder;

public class Lantern extends Client.SocketProvider.Stub {

    private static final String TAG = "Lantern";
    final private LanternVpn service;
    final private Analytics analytics;

    private String device, model, version;
    private Context context;

    private final static String DEFAULT_DNS_SERVER = "8.8.4.4";

    private Client.GoCallback.Stub callback;

    public Lantern(LanternVpn service) {
        this.service = service;
        this.context = service.getApplicationContext();
        this.analytics = new Analytics(this.context);
        this.setupCallbacks();
        this.device = android.os.Build.DEVICE;
        this.model = android.os.Build.MODEL;
        this.version = "" + android.os.Build.VERSION.SDK_INT + " ("  + android.os.Build.VERSION.RELEASE + ")";
    }

    // Configures callbacks from Lantern during packet
    // processing
    private void setupCallbacks() {

        final Analytics analytics = this.analytics;

        final LanternVpn service = this.service;

        this.callback = new Client.GoCallback.Stub() {

            public String GetDnsServer() {
                return DEFAULT_DNS_SERVER;
                /*
                try {
                    return service.getDnsResolver(service);
                } catch (Exception e) {
                    return DEFAULT_DNS_SERVER;
                }
                */
            }

            public void AfterStart(String latestVersion) {
                Log.d(TAG, "Lantern successfully started.");
                analytics.sendNewSessionEvent();
            }

            public void AfterConfigure() {
                Log.d(TAG, "Lantern successfully configured.");
            }
        };
    }

    public void start() {
        try {
            Log.d(TAG, "About to start Lantern..");

            String httpAddr = String.format("127.0.0.1:%d", LanternConfig.HTTP_PORT);
            String socksAddr = String.format("127.0.0.1:%d", LanternConfig.SOCKS_PORT);

            if (VpnBuilder.USE_LANTERN_SOCKS) {
                Client.StartWithSocks(this, httpAddr, socksAddr, LanternConfig.APP_NAME, this.device, this.model, this.version, callback);
            } else {
                Client.StartWithTunio(this, httpAddr, LanternConfig.APP_NAME, this.device, this.model, this.version, callback);
            }

        } catch (final Exception e) {
            Log.e(TAG, "Fatal error while trying to run Lantern: " + e);
            throw new RuntimeException(e);
        }
    }

    public void stop() {
        Log.d(TAG, "About to stop Lantern..");
        try {
            Client.StopClientProxy();
        } catch(final Exception e) {
            // ignore exception
        }
    }

    @Override
    // Notice is used to signal messages from Lantern
    // if fatal is true, Lantern encountered a fatal error
    // and we should shutdown
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
