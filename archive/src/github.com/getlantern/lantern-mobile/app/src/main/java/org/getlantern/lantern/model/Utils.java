package org.getlantern.lantern.model;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.inputmethod.InputMethodManager;

import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentActivity;

import com.google.android.gms.analytics.HitBuilders;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.getlantern.lantern.R;
import org.getlantern.lantern.fragment.ErrorDialogFragment;
import org.lantern.mobilesdk.Lantern;

public class Utils {
    private static final String PREFS_NAME = "LanternPrefs";
    private static final String TAG = "Utils";
    private static final String PREF_USE_VPN = "pref_vpn";

    // update START/STOP power Lantern button
    // according to our stored preference
    public static SharedPreferences getSharedPrefs(Context context) {
        return context.getSharedPreferences(PREFS_NAME,
                Context.MODE_PRIVATE);
    }

    public static void clearPreferences(Context context) {
        SharedPreferences mPrefs = getSharedPrefs(context);

        if (mPrefs != null) {
            mPrefs.edit().remove(PREF_USE_VPN).commit();
        }
    }

    public static void hideKeyboard(Context context, View view) {
        InputMethodManager inputMethodManager = (InputMethodManager)context.getSystemService(Activity.INPUT_METHOD_SERVICE);
        inputMethodManager.hideSoftInputFromWindow(view.getWindowToken(), 0);
    }

    public static void showErrorDialog(final FragmentActivity activity, String error) {
        DialogFragment fragment = ErrorDialogFragment.newInstance(R.string.validation_errors, error);
        fragment.show(activity.getSupportFragmentManager(), "error");
    }

    public static boolean isEmailValid(String email) {
        String expression = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{2,4}$";
        Pattern pattern = Pattern.compile(expression, Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(email);
        return matcher.matches();
    }

    public static void showAlertDialog(Activity activity, String title, String msg) {
        Log.d(TAG, "Showing alert dialog...");

        AlertDialog alertDialog = new AlertDialog.Builder(activity).create();
        alertDialog.setTitle(title);
        alertDialog.setMessage(msg);
        alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL, "OK",
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        dialog.dismiss();
                    }
        }
        );
        alertDialog.show();
    }

    // isNetworkAvailable checks whether or not we are connected to
    // the Internet; if no connection is available, the toggle
    // switch is inactive
    public static boolean isNetworkAvailable(final Context context) {
        final ConnectivityManager connectivityManager = 
            ((ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE));
        return connectivityManager.getActiveNetworkInfo() != null && 
            connectivityManager.getActiveNetworkInfo().isConnectedOrConnecting();
    }

    public static void sendFeedEvent(Context context, String category) {
        Log.d(TAG, "Logging feed event. Category is " + category);

        String analyticsTrackingID = "UA-21815217-14";
        Lantern.trackerFor(context, analyticsTrackingID).send(new HitBuilders.EventBuilder()
                .setCategory(category)
                .setAction("click")
                .build());
    }
}
