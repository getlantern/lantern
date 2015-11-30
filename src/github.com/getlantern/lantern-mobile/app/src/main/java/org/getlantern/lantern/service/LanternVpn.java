package org.getlantern.lantern.service;

import android.content.Intent;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.widget.Toast;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.Map;

import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.model.Lantern;
import org.getlantern.lantern.model.LanternUI;
import org.getlantern.lantern.model.Utils;
import org.getlantern.lantern.model.VpnBuilder;

public class LanternVpn extends VpnBuilder implements Handler.Callback {
    private static final String TAG = "LanternVpn";

    private String mSessionName = "LanternVpn";

    private Handler mHandler;
    private Thread mThread;

    private Lantern lantern = null;

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {

        if (intent == null) {
            return START_STICKY;
        }

        if (lantern == null) {
            lantern = new Lantern(this); 
        }

        String action = intent.getAction();

        // STOP button was pressed
        // shut down Lantern and close the VPN connection
        if (action.equals(LanternConfig.DISABLE_VPN)) {

            stop();

            if (mHandler != null) {
                mHandler.postDelayed(new Runnable () {
                    public void run () { 
                        stopSelf();
                    }
                }, 1000);
            }

            return START_STICKY;
        }

        // Stop the previous session by interrupting the thread.
        if (mThread != null) {
            mThread.interrupt();
        }


        // The handler is only used to show messages.
        if (mHandler == null) {
            mHandler = new Handler(this);
        }


        // Make sure we check for null here
        // as on start command can run multiple times
        if (mThread == null || (!mThread.isAlive())) {
            start();
        }
        return START_STICKY;
    }

    private synchronized void start() {
        Log.d(TAG, "Loading Lantern library");
        final LanternVpn service = this;
        mThread = new Thread() {
            public void run() {
                try {

                    lantern.start();
                    Thread.sleep(2000);
                    service.configure(lantern.getSettings());

                } catch (Exception uhe) {
                    Log.e(TAG, "Error starting Lantern with given host: " + uhe);
                }
            }
        };
        mThread.start();
    }

    public void stop() {
        try {
            if (lantern != null) {
                lantern.stop(); 
                lantern = null;
            }
            Log.d(TAG, "Closing VPN interface and stopping Lantern..");
            Utils.clearPreferences(this);

            Thread.sleep(2000);

            super.close();

            mThread = null;
        } catch (Exception e) {
            Log.e(TAG, "Could not stop Lantern: " + e);
        }
    }

    public void setVersionNum(String latestVersion) {
        UI.setVersionNum(latestVersion);
    }

    @Override
    public void onDestroy() {
        if (mThread != null) {
            mThread.interrupt();
        }

        try {
            stop();
        } catch (Exception e) {

        }
    }

    @Override
    public boolean handleMessage(Message message) {
        if (message != null) {
            Toast.makeText(this, message.what, Toast.LENGTH_SHORT).show();
        }
        return true;
    }
}
