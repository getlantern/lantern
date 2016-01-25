package org.getlantern.lantern.vpn;

import android.content.Intent;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.widget.Toast;

import android.content.Context;
import android.content.SharedPreferences;

import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.sdk.Utils;

import java.util.Map;

public class Service extends VpnBuilder implements Runnable {

    private static final String TAG = "VpnService";
    public static boolean IsRunning = false;

    private String mSessionName = "LanternVpn";

    private Handler mHandler;
    private LanternVpn lantern;
    private Thread mThread = null;

    public Service() {
        mHandler = new Handler();
    }

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
            final Service service = this;
            lantern = new LanternVpn(this);
            lantern.Start();

            Thread.sleep(1000*2);
            service.configure(lantern.getSettings());

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
            lantern.Stop();
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
