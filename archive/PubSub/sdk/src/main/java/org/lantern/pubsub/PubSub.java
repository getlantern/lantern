package org.lantern.pubsub;

import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.util.Log;

/**
 * API for using the Lantern pubsub infrastructure from Android.
 */
public class PubSub {
    private static final String TAG = "PubSub";

    public static final String SERVICE_STARTED_INTENT = "org.lantern.pubsub.intent.SERVICE_STARTED";
    public static final String SUBSCRIBE_INTENT = "org.lantern.pubsub.intent.SUBSCRIBE";
    public static final String MESSAGE_RECEIVED_INTENT = "org.lantern.pubsub.intent.MESSAGE_RECEIVED";

    static final String TOPIC = "topic";
    static final String BODY = "body";

    /**
     * Utility method for getting the topic from a message received intent.
     *
     * @param intent
     * @return
     */
    public static byte[] topic(Intent intent) {
        return intent.getByteArrayExtra(TOPIC);
    }

    /**
     * Utility method for getting the body from a message received intent.
     *
     * @param intent
     * @return
     */
    public static byte[] body(Intent intent) {
        return intent.getByteArrayExtra(BODY);
    }

    /**
     * Starts the PubSub service (okay to call multiple times).
     *
     * @param context
     */
    public static void start(Context context) {
        Log.i(TAG, "Starting");

        IntentFilter filter = new IntentFilter();
        filter.addAction(MESSAGE_RECEIVED_INTENT);

        Intent intent = new Intent(context, PubSubService.class);
        context.startService(intent);
        Log.i(TAG, "Start succeeded");
    }

    /**
     * Subscribes to a topic.
     *
     * @param context
     * @param topic
     */
    public static void subscribe(Context context, byte[] topic) {
        Log.i(TAG, "Subscribing");
        Intent intent = new Intent(SUBSCRIBE_INTENT);
        intent.putExtra(TOPIC, topic);
        context.sendBroadcast(intent);
    }
}
