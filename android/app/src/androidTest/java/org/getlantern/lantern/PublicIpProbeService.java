package org.getlantern.lantern;

import android.app.Service;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Messenger;
import android.os.Process;
import android.os.ResultReceiver;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Reports its public IP and whether its traffic uses a VPN. It runs in the test
 * APK's own process, which Lantern's VPN covers; Lantern's process is excluded.
 * Java, not Kotlin: the test APK doesn't bundle the Kotlin runtime, which only
 * the app's process provides.
 */
public final class PublicIpProbeService extends Service {
    public static final String REPLY = "reply";
    public static final String UID = "uid";
    public static final String VPN = "vpn";
    public static final String IP = "ip";
    public static final String ERROR = "error";

    @SuppressWarnings("deprecation")
    private final Messenger messenger = new Messenger(new Handler(Looper.getMainLooper(), message -> {
        ResultReceiver reply = message.getData().getParcelable(REPLY);
        if (reply != null) probe(reply);
        return true;
    }));

    @Override
    public IBinder onBind(Intent intent) {
        return messenger.getBinder();
    }

    private void probe(ResultReceiver reply) {
        new Thread(() -> {
            Bundle result = new Bundle();
            result.putInt(UID, Process.myUid());
            try {
                ConnectivityManager connectivity = getSystemService(ConnectivityManager.class);
                NetworkCapabilities capabilities = connectivity.getNetworkCapabilities(connectivity.getActiveNetwork());
                result.putBoolean(VPN, capabilities != null && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN));
                HttpURLConnection connection = (HttpURLConnection) new URL("https://api.ipify.org?nonce=" + System.nanoTime()).openConnection();
                try {
                    connection.setConnectTimeout(10_000);
                    connection.setReadTimeout(10_000);
                    connection.setUseCaches(false);
                    try (BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream()))) {
                        result.putString(IP, reader.readLine().trim());
                    }
                } finally {
                    connection.disconnect();
                }
            } catch (Exception e) {
                result.putString(ERROR, e.toString());
            }
            reply.send(0, result);
        }, "public-ip-probe").start();
    }
}
