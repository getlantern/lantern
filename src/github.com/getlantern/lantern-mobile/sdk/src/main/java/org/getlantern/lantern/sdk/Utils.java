package org.getlantern.lantern.sdk;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.content.res.AssetManager;
import android.content.res.Resources;
import android.os.Looper;
import android.util.Log;
import android.view.View.OnClickListener;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.io.InputStream;

import java.util.Map;
import java.util.HashMap;

import org.yaml.snakeyaml.Yaml;


public class Utils {
    private static final String PREFS_NAME = "LanternPrefs";
    private static final String TAG = "Utils";
    private final static String PREF_USE_VPN = "pref_vpn";


    // update START/STOP power Lantern button
    // according to our stored preference
    public static SharedPreferences getSharedPrefs(Context context) {
        return context.getSharedPreferences(PREFS_NAME,
                Context.MODE_PRIVATE);
    }

    public static Map loadSettings(Context context, String filename) {

        InputStream in = null;
        OutputStream out = null;
        Map settings = new HashMap();

        try {
            Resources resources = context.getResources();
            String packageName = context.getPackageName();

            String resourceName = filename.substring(0, filename.lastIndexOf('.'));

            in = resources.openRawResource(
                    resources.getIdentifier("raw/" + resourceName,
                        "raw", packageName));

            Yaml yaml = new Yaml();
            settings = (Map)yaml.load(in);

            String newFileName = context.getFilesDir() + "/" + filename;

            out = new FileOutputStream(newFileName);

            byte[] buffer = new byte[1024];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            in.close();
            in = null;
            out.flush();
            out.close();
            out = null;

            Log.d(TAG, "Finished copying file to new destination: " + filename);
        } catch (Exception e) {
            Log.e(TAG, "Unable to load settings file " + e.getMessage());
        }

        return settings;
    }

    public static void showAlertDialog(Activity activity, String title, String msg) {
        Log.d(TAG, "Showing alert dialog...");
        if (Looper.myLooper() == null) {
            Looper.prepare();
        }

        AlertDialog alertDialog = new AlertDialog.Builder(activity).create();
        alertDialog.setTitle("Lantern");
        alertDialog.setMessage(msg);
        alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL, "OK",
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int which) {
                        dialog.dismiss();
                    }
                });
        alertDialog.show();

        Looper.loop();
    }


    public static void clearPreferences(Context context) {

        SharedPreferences mPrefs = getSharedPrefs(context);

        if (mPrefs != null) {
            mPrefs.edit().remove(PREF_USE_VPN).commit();
        }
    }
}
