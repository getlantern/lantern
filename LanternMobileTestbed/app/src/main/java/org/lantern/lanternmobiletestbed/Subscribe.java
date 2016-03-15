package org.lantern.lanternmobiletestbed;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import org.lantern.pubsub.Client;
import org.lantern.pubsub.PubSub;

/**
 * Subscribes to notifications.
 */
public class Subscribe extends BroadcastReceiver {
    public void onReceive(Context context, Intent intent) {
        PubSub.subscribe(context, Client.utf8("topic"));
    }
}