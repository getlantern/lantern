package org.lantern.lanternmobiletestbed;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.TaskStackBuilder;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.support.v4.app.NotificationCompat;
import android.util.Log;

import org.lantern.pubsub.Client;
import org.lantern.pubsub.PubSub;

/**
 * Handles notifications.
 */
public class Notify extends BroadcastReceiver {
    private static final String TAG = "Notify";

    public void onReceive(Context context, Intent intent) {
        Log.i(TAG, "Notifying");

        final int notificationId = 100;
        final Resources resources = context.getResources();
        Bitmap largeIcon = getBitmap(resources, R.drawable.lantern_icon);

        // See http://developer.android.com/guide/topics/ui/notifiers/notifications.html
        NotificationCompat.Builder mBuilder =
                new NotificationCompat.Builder(context)
                        .setColor(Color.rgb(41,188,210))
                        .setSmallIcon(R.drawable.notification_icon)
                        .setContentTitle("Lantern Notification")
                        .setContentText(Client.fromUTF8(PubSub.body(intent)))
                        .setAutoCancel(true);
        // Creates an explicit intent for an Activity in your app
        Intent resultIntent = new Intent(context, Browse.class);
        PendingIntent resultPendingIntent = null;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
            // The stack builder object will contain an artificial back stack for the
            // started Activity.
            // This ensures that navigating backward from the Activity leads out of
            // your application to the Home screen.
            TaskStackBuilder stackBuilder = TaskStackBuilder.create(context);
            // Adds the back stack for the Intent (but not the Intent itself)
            stackBuilder.addParentStack(Browse.class);
            // Adds the Intent that starts the Activity to the top of the stack
            stackBuilder.addNextIntent(resultIntent);
            resultPendingIntent = stackBuilder.getPendingIntent(
                    0,
                    PendingIntent.FLAG_UPDATE_CURRENT);
        } else {
            resultPendingIntent = PendingIntent.getActivity(context, 0, resultIntent, PendingIntent.FLAG_UPDATE_CURRENT);
        }
        mBuilder.setContentIntent(resultPendingIntent);

        NotificationManager mNotificationManager =
                (NotificationManager) context.getSystemService(android.content.Context.NOTIFICATION_SERVICE);
        Notification notification = mBuilder.build();
//        notification.contentView.setImageViewBitmap(android.R.id.icon, largeIcon);
        mNotificationManager.notify(notificationId, notification);
    }

    /**
     * See https://android.googlesource.com/platform/packages/experimental/+/363b69b578809b2d5f7ea49d186197797590fac4/NotificationShowcase/src/com/android/example/notificationshowcase/NotificationShowcaseActivity.java for example.
     */
    private Bitmap getBitmap(Resources resources, int iconId) {
        int width = (int) resources.getDimension(android.R.dimen.notification_large_icon_width);
        int height = (int) resources.getDimension(android.R.dimen.notification_large_icon_height);
        Drawable d = resources.getDrawable(iconId);
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas c = new Canvas(bitmap);
        d.setBounds(0, 0, width, height);
        d.draw(c);
        return bitmap;
    }
}