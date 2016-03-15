package org.lantern.pubsub;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;

import java.util.Collections;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * API for using the Lantern pubsub infrastructure from Android.
 */
public class PubSub {
    private static final String TAG = "PubSub";

    public static final String MESSAGE_RECEIVED_INTENT = "org.getlantern.pubsub.MESSAGE_RECEIVED_INTENT";
    public static final String TOPIC = "topic";
    public static final String BODY = "body";
    public static final String JSHANDLER = "jshandler";

    // HandlerThread used to handle broadcasts from service
    private static final HandlerThread HANDLER_THREAD;

    private static final Set<MessageHandler> handlers = Collections.newSetFromMap(new ConcurrentHashMap<MessageHandler, Boolean>());

    static {
        HANDLER_THREAD = new HandlerThread("PubSubService-BroadcastHandler");
        HANDLER_THREAD.start();
    }

    /**
     * Subscribes to a topic and registers the given {@link MessageHandler} to receive messages for
     * that topic. The MessageHandler will run in the context of the containing application.
     *
     * @param context
     * @param topic
     * @param handler
     */
    public static void subscribe(Context context, byte[] topic, MessageHandler handler) {
        subscribe(context, topic, handler, null);
    }

    /**
     * Subscribes to a given topic and registers the given
     * @param context
     * @param topic
     * @param jshandler
     */
    public static void subscribe(Context context, byte[] topic, String jshandler) {
        subscribe(context, topic, null, jshandler);
    }

    public static void subscribe(Context context, byte[] topic, MessageHandler handler, String jshandler) {
        Log.i(TAG, "Subscribing/starting");

        if (handler != null) {
            Log.i(TAG, "Registering handler");
            handlers.add(handler);
        }

        IntentFilter filter = new IntentFilter();
        filter.addAction(MESSAGE_RECEIVED_INTENT);

        // Note - we register the receiver on a separate thread to avoid deadlocking on the main
        // thread (should this method be called from the main thread).
        context.registerReceiver(new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                Message msg = new Message(Type.Publish, intent.getByteArrayExtra(TOPIC), intent.getByteArrayExtra(BODY));
                for (MessageHandler handler : handlers) {
                    handler.onMessage(msg);
                }
            }
        }, filter, null, new Handler(HANDLER_THREAD.getLooper()));

        Intent intent = serviceIntent(context);
        intent.putExtra(TOPIC, topic);
        if (jshandler != null) {
            Log.i(TAG, "Registering jshandler");
        }
        intent.putExtra(JSHANDLER, jshandler);
        context.startService(intent);
        Log.i(TAG, "Start succeeded");
    }

    private static Intent serviceIntent(Context context) {
        Intent intent = new Intent();
        intent.setComponent(new ComponentName(context, "org.lantern.pubsub.PubSubService"));
        return intent;
    }
}
