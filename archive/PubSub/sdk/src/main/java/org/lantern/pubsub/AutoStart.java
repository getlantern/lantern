package org.lantern.pubsub;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * BroadcastReceiver to support automatically listening for notifications on phone start, patterned
 * after the advice here - http://stackoverflow.com/questions/7690350/android-start-service-on-boot.
 */
public class AutoStart extends BroadcastReceiver {
    private static final String TAG = "AutoStart";

    public void onReceive(Context context, Intent intent) {
        Log.i(TAG, "Auto starting");
        PubSub.start(context);
    }
}