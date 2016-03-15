package org.lantern.pubsub;

import android.app.IntentService;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.TaskStackBuilder;
import android.content.ComponentName;
import android.content.ContextWrapper;
import android.content.Intent;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.support.v4.app.NotificationCompat;
import android.util.Log;

import org.mozilla.javascript.Context;
import org.mozilla.javascript.Scriptable;
import org.mozilla.javascript.ScriptableObject;

import java.nio.ByteBuffer;
import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Background service that receives pubsub notifications and notifies {@link PubSub}.
 */
public class PubSubService extends IntentService {
    private static final String TAG = "PubSubService";

    private final AtomicBoolean running = new AtomicBoolean();
    private volatile Client client;
    private Map<ByteBuffer, Set<String>> jsHandlers = new ConcurrentHashMap<ByteBuffer, Set<String>>();

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
                    sendBroadcast(messageIntent);
                    handleWithJS(msg);
                } catch (InterruptedException ie) {
                    ie.printStackTrace();
                    running.set(false);
                    return;
                }
            }
        }
    };

    public PubSubService() {
        super("PubSubService");
    }

    @Override
    protected synchronized void onHandleIntent(Intent intent) {
        Log.i(TAG, "Start requested");
        if (running.compareAndSet(false, true)) {
            Log.i(TAG, "Starting");
            initClient();
        } else {
            Log.i(TAG, "Already started");
        }

        byte[] topic = intent.getByteArrayExtra(PubSub.TOPIC);

        String jsHandler = intent.getStringExtra(PubSub.JSHANDLER);
        if (jsHandler != null) {
            Log.i(TAG, "Registering JavaScript handler");
            Set<String> handlers = jsHandlers.get(ByteBuffer.wrap(topic));
            if (handlers == null) {
                handlers = Collections.newSetFromMap(new ConcurrentHashMap<String, Boolean>());
                jsHandlers.put(ByteBuffer.wrap(topic), handlers);
            }
            handlers.add(jsHandler);
        }

        try {
            client.subscribe(topic);
            Log.i(TAG, "Subscribed");
        } catch (InterruptedException ie) {
            Log.e(TAG, "Unable to subscribe, interrupted", ie);
        }
    }

    private void initClient() {
        Client.ClientConfig config = new Client.ClientConfig("pubsub.lantern.io", 14443);
        client = new Client(config);
        reader.start();
    }

    private void handleWithJS(Message msg) {
        Set<String> handlers = jsHandlers.get(ByteBuffer.wrap(msg.getTopic()));
        if (handlers == null) {
            return;
        }

        // See http://lifeofcoding.com/2015/04/05/Execute-JavaScript-in-Android-without-WebView/ for
        // tips on Rhino.
        for (String jshandler : handlers) {
            Context rhino = Context.enter();
            rhino.setOptimizationLevel(-1);
            try {
                Scriptable scope = rhino.initSafeStandardObjects();
                ScriptableObject.putProperty(scope, "pubsub", Context.javaToJS(notifier, scope));
                ScriptableObject.putProperty(scope, "topic", msg.getTopic());
                ScriptableObject.putProperty(scope, "body", msg.getBody());
                rhino.evaluateString(scope, jshandler, "JSHandler", 1, null);
            } catch (Exception e) {
                Log.e(TAG, "Unable to evaluate jshandler: " + e.getMessage(), e);
            }
        }
    }

    private final Notifier notifier = new Notifier();

    public class Notifier {
        public void doIt() {
            Log.i(TAG, "Doing it!");
        }

        /**
         * Displays an android notification.
         *
         * @param pkg      the package containing the icon resources as well as the activity to open in response to the notification.
         * @param icon     the name of the drawable for the icon (used for both small and large icon)
         * @param title    the title of the notification
         * @param body     the body of the notification
         * @param activity the unqualified class name of the activity to launch in response to the notification
         * @param id       the application-specific id for the notification (todo - may want to auto-generate this)
         * @throws Exception
         */
        public void notify(final String pkg, final String icon, final String title, final String body, final String activity, final int id) throws Exception {
            final Resources resources = getApplicationContext().getPackageManager().getResourcesForApplication(pkg);
            int iconId = resources.getIdentifier(icon, "drawable", pkg);
            Bitmap largeIcon = getBitmap(resources, iconId);
            ComponentName activityName = new ComponentName(pkg, pkg + "." + activity);

            // See http://developer.android.com/guide/topics/ui/notifiers/notifications.html
            NotificationCompat.Builder mBuilder =
                    new NotificationCompat.Builder(new ContextWrapper(getApplicationContext()) {
                        @Override
                        public Resources getResources() {
                            return resources;
                        }
                    })
                            .setSmallIcon(iconId)
                            .setLargeIcon(largeIcon)
                            .setContentTitle(title)
                            .setContentText(body)
                            .setAutoCancel(true);
            // Creates an explicit intent for an Activity in your app
            Intent resultIntent = new Intent();
            resultIntent.setComponent(activityName);
            PendingIntent resultPendingIntent = null;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                // The stack builder object will contain an artificial back stack for the
                // started Activity.
                // This ensures that navigating backward from the Activity leads out of
                // your application to the Home screen.
                TaskStackBuilder stackBuilder = TaskStackBuilder.create(getApplicationContext());
                // Adds the back stack for the Intent (but not the Intent itself)
                stackBuilder.addParentStack(activityName);
                // Adds the Intent that starts the Activity to the top of the stack
                stackBuilder.addNextIntent(resultIntent);
                resultPendingIntent = stackBuilder.getPendingIntent(
                        id,
                        PendingIntent.FLAG_UPDATE_CURRENT);
            } else {
                resultPendingIntent = PendingIntent.getActivity(getApplicationContext(), id, resultIntent, PendingIntent.FLAG_UPDATE_CURRENT);
            }
            mBuilder.setContentIntent(resultPendingIntent);

            NotificationManager mNotificationManager =
                    (NotificationManager) getSystemService(android.content.Context.NOTIFICATION_SERVICE);
            // mId allows you to update the notification later on.
            mNotificationManager.notify(5, mBuilder.build());
        }

        public String fromUTF8(byte[] bytes) {
            return Client.fromUTF8(bytes);
        }

        /**
         * See https://android.googlesource.com/platform/packages/experimental/+/363b69b578809b2d5f7ea49d186197797590fac4/NotificationShowcase/src/com/android/example/notificationshowcase/NotificationShowcaseActivity.java for example.
         */
        private Bitmap getBitmap(Resources resources, int iconId) {
            int width = (int) getResources().getDimension(android.R.dimen.notification_large_icon_width);
            int height = (int) getResources().getDimension(android.R.dimen.notification_large_icon_height);
            Drawable d = resources.getDrawable(iconId);
            Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            Canvas c = new Canvas(bitmap);
            d.setBounds(0, 0, width, height);
            d.draw(c);
            return bitmap;
        }
    }
}