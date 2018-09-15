package org.lantern.pubsub;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.IBinder;
import android.support.annotation.Nullable;
import android.util.Log;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Background service that receives pubsub notifications and notifies {@link PubSub}.
 */
public class PubSubService extends Service {
    private static final String TAG = "PubSubService";

    private final AtomicBoolean running = new AtomicBoolean();
    private volatile Client client;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i(TAG, "Start requested");
        int result = super.onStartCommand(intent, flags, startId);
        if (running.compareAndSet(false, true)) {
            Log.i(TAG, "Starting");
            initClient();
            registerSubscribeReceiver();
            Intent startedIntent = new Intent(PubSub.SERVICE_STARTED_INTENT);
            sendBroadcast(startedIntent);
            Log.i(TAG, "Started");
        } else {
            Log.i(TAG, "Already started");
        }
        return result;
    }

    private void initClient() {
        Client.ClientConfig config = new Client.ClientConfig("pubsub-test.lantern.io", 14443);
        client = new Client(config);
        reader.start();
    }

    private final Thread reader = new Thread() {
        @Override
        public void run() {
            while (true) {
                try {
                    Message msg = client.read();
                    Intent messageIntent = new Intent(PubSub.MESSAGE_RECEIVED_INTENT);
                    messageIntent.putExtra(PubSub.TOPIC, msg.getTopic());
                    messageIntent.putExtra(PubSub.BODY, msg.getBody());
                    Log.i(TAG, "Notifying of message");
                    // TODO: right now, this publishes all messages in a way that anyone listening
                    // for this intent can read them. Once we have multiple clients using a single
                    // PubSubService, we should make sure to isolate them so they can't see each
                    // others' notifications.
                    sendBroadcast(messageIntent);
                } catch (InterruptedException ie) {
                    ie.printStackTrace();
                    running.set(false);
                    return;
                }
            }
        }
    };

    private void registerSubscribeReceiver() {
        Log.i(TAG, "Registering Subscribe Receiver");
        IntentFilter filter = new IntentFilter();
        filter.addAction(PubSub.SUBSCRIBE_INTENT);

        getApplicationContext().registerReceiver(new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                Log.i(TAG, "Subscribing");
                try {
                    client.subscribe(PubSub.topic(intent));
                    Log.i(TAG, "Subscribed");
                } catch (InterruptedException ie) {
                    Log.e(TAG, "Unable to subscribe: " + ie.getMessage(), ie);
                }
            }
        }, filter);

        Log.i(TAG, "Registered Subscribe Receiver");
    }
}