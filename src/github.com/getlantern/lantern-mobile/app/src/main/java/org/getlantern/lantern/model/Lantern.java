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

    private BlockingQueue<byte[]> packets;

    //
    public Lantern(LanternVpn service) {
        this.service = service;
        this.setupCallbacks();
        // this is the queue where we write
        // incoming packets to
        this.packets = new LinkedBlockingQueue<>();
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

            public void WritePacket(byte[] bytes) {
                try {
                    packets.put(bytes);
                } catch (InterruptedException ie) {
                    Log.e(TAG, "Unable to write packet to response channel");
                } catch (IllegalStateException e) {
                    Log.e(TAG, "Error writing packet to output stream.");
                }
            }
        };
    }

    public void start() {
        try {
            Log.d(TAG, "About to start Lantern..");
            String httpAddr = String.format("127.0.0.1:%d", LanternConfig.HTTP_PORT);
            String socksAddr = String.format("127.0.0.1:%d", LanternConfig.SOCKS_PORT);

            Client.RunClientProxy(httpAddr,
                    LanternConfig.APP_NAME, this, callback);
            // Wait a few seconds for processing until Lantern starts
            Thread.sleep(3000);
            // Configure Lantern and interception rules
            Client.Configure(this, httpAddr, socksAddr, LanternConfig.UDPGW_SERVER, callback);

        } catch (final Exception e) {
            Log.e(TAG, "Fatal error while trying to run Lantern: " + e);
            throw new RuntimeException(e);
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

    public int readPacket(final ByteBuffer packet) {
        if (this.packets.size() > 0) {
            byte[] response = this.packets.poll(); 
            if (response != null) {
                int length = response.length;
                packet.put(response);
                return length;
            }
        }
        return 0;
    }
}
