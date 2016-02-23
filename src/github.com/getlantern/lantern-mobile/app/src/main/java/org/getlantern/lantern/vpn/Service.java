package org.getlantern.lantern.vpn;

import android.content.Intent;
import android.util.Log;

import go.lantern.Lantern;

public class Service extends VpnBuilder implements Runnable {

    private static final String TAG = "VpnService";
    public static boolean IsRunning = false;

    private Thread mThread = null;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "VpnService created");
        mThread = new Thread(this, "VpnService");
        mThread.start();
    }


    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        IsRunning = true;
        return super.onStartCommand(intent, flags, startId);
    }

    @Override
    public synchronized void run() {
        try {
            Log.d(TAG, "Loading Lantern library");
            Lantern.ProtectConnections(getDnsResolver(getApplicationContext()), new Lantern.SocketProtector.Stub() {
                // Protect is used to exclude a socket specified by fileDescriptor
                // from the VPN connection. Once protected, the underlying connection
                // is bound to the VPN device and won't be forwarded
                @Override
                public void Protect(long fileDescriptor) throws Exception {
                    if (!protect((int) fileDescriptor)) {
                        throw new Exception("protect socket failed");
                    }
                }
            });
            int startTimeoutMillis = 60000;
            String analyticsTrackingID = "UA-21815217-14";
            org.lantern.mobilesdk.StartResult result = org.lantern.mobilesdk.Lantern.enable(getApplicationContext(), startTimeoutMillis, analyticsTrackingID);
            configure(result.getSOCKS5Addr());

            while (IsRunning) {
                // sleep to avoid busy looping
                Thread.sleep(100);
            }
        } catch (InterruptedException e) {
            Log.e(TAG, "Exception", e);
        } catch (Exception e) {
            e.printStackTrace();
            Log.e(TAG, "Fatal error", e);
        } finally {
            Log.e(TAG, "Lantern terminated.");
            stop();
        }
    }

    private synchronized void stop() {
        try {
            super.close();
            Log.d(TAG, "Closing VPN interface..");
        } catch (Exception e) {
        }

        stopSelf();
        IsRunning = false;
    }

    @Override
    public void onDestroy() {
        Log.d(TAG, "Lantern VpnService destroyed");
        if (mThread != null) {
            mThread.interrupt();
        }
    }
}
