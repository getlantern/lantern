package org.lantern.mobilesdk.service;

import android.app.IntentService;
import android.content.Intent;
import android.util.Log;

import org.lantern.mobilesdk.LanternNotRunningException;
import org.lantern.mobilesdk.LanternServiceManager;
import org.lantern.mobilesdk.StartResult;
import org.lantern.mobilesdk.embedded.EmbeddedLantern;

/**
 * Service that allows running {@link EmbeddedLantern} in the background. Whenever someone attempts
 * to start the service, it starts Lantern and broadcasts the result so that
 * {@link LanternServiceManager} knows at what address to find the proxy (or how to report an error
 * if Lantern failed to start).
 */
public class LanternService extends IntentService {
    private static final String TAG = "LanternService";

    public LanternService() {
        super("LanternService");
    }

    @Override
    protected void onHandleIntent(Intent intent) {
        Log.i(TAG, "Starting");
        String configDir = intent.getStringExtra(LanternServiceManager.CONFIG_DIR);
        int timeoutMillis = intent.getIntExtra(LanternServiceManager.TIMEOUT_MILLIS, 0);
        try {
            StartResult result = new EmbeddedLantern().start(configDir, timeoutMillis);
            Intent resultIntent = new Intent(LanternServiceManager.LANTERN_STARTED_INTENT);
            resultIntent.putExtra(LanternServiceManager.HTTP_ADDR, result.getHTTPAddr());
            resultIntent.putExtra(LanternServiceManager.SOCKS5_ADDR, result.getSOCKS5Addr());
            Log.i(TAG, "Notifying of successful start");
            sendBroadcast(resultIntent);
        } catch (LanternNotRunningException lnre) {
            Intent resultIntent = new Intent(LanternServiceManager.LANTERN_NOT_STARTED_INTENT);
            resultIntent.putExtra(LanternServiceManager.ERROR, lnre.getMessage());
            Log.i(TAG, "Notifying of failed start");
            sendBroadcast(resultIntent);
        }
    }
}