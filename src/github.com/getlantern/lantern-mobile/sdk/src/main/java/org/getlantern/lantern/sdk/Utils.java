package org.getlantern.lantern.sdk;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.AssetManager;
import android.content.res.Resources;
import android.util.Log;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.io.InputStream;

import java.util.Map;
import java.util.HashMap;

import org.yaml.snakeyaml.Yaml;

import org.apache.commons.io.FilenameUtils;

import org.getlantern.lantern.sdk.LanternConfig;

public class Utils {
    private static final String PREFS_NAME = "LanternPrefs";
    private static final String TAG = "Utils";


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

            String resourceName = FilenameUtils.removeExtension(filename);

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

    public static void clearPreferences(Context context) {

        SharedPreferences mPrefs = getSharedPrefs(context);

        if (mPrefs != null) {
            mPrefs.edit().remove(LanternConfig.PREF_USE_VPN).commit();
        }
    }
}
