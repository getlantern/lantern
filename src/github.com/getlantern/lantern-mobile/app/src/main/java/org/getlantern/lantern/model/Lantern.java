package org.getlantern.lantern.model;

import android.util.Log;

import java.net.InetAddress;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.BlockingQueue;

import go.client.*;
import org.getlantern.lantern.service.LanternVpn;
import org.getlantern.lantern.config.LanternConfig;

public class Lantern extends Client.SocketProvider.Stub {

    private static final String TAG = "Lantern";
    private LanternVpn service;
    private Client.GoCallback.Stub callback;

    public Lantern(LanternVpn service) {
        this.service = service;
        this.setupCallbacks();
    }

    // Configures callbacks from Lantern during packet
    // processing
    private void setupCallbacks() {
        final Lantern service = this;
        this.callback = new Client.GoCallback.Stub() {
            public void AfterStart() {
                Log.d(TAG, "Lantern successfully started.");
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

            Client.RunClientProxy(httpAddr, LanternConfig.APP_NAME, this, callback);

            // Wait a second for processing until Lantern starts
            Thread.sleep(1000);
            // Configure Lantern and interception rules
            Client.Configure(this, httpAddr, socksAddr, LanternConfig.UDPGW_SERVER, callback);

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
