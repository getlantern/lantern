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

public final class SplitTunnelProbeService extends Service {
    @SuppressWarnings("deprecation")
    private final Messenger messenger = new Messenger(new Handler(Looper.getMainLooper(), message -> {
        ResultReceiver reply = message.getData().getParcelable("reply");
        if (reply != null) probe(reply);
        return true;
    }));

    @Override
    public IBinder onBind(Intent intent) {
        return messenger.getBinder();
    }

    private void probe(ResultReceiver reply) {
        new Thread(() -> {
            Bundle response = new Bundle();
            response.putInt("uid", Process.myUid());
            try {
                ConnectivityManager connectivity = getSystemService(ConnectivityManager.class);
                NetworkCapabilities capabilities = connectivity.getNetworkCapabilities(connectivity.getActiveNetwork());
                response.putBoolean("vpn", capabilities != null && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN));
                HttpURLConnection connection = (HttpURLConnection) new URL("https://api.ipify.org?nonce=" + System.nanoTime()).openConnection();
                try {
                    connection.setConnectTimeout(10000);
                    connection.setReadTimeout(10000);
                    connection.setUseCaches(false);
                    try (BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream()))) {
                        response.putString("ip", reader.readLine().trim());
                    }
                } finally {
                    connection.disconnect();
                }
            } catch (Exception e) {
                response.putString("error", e.toString());
            }
            reply.send(0, response);
        }, "split-tunnel-probe").start();
    }
}
