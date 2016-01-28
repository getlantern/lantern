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

public class Utils {
    private static final String PREFS_NAME = "LanternPrefs";
    private static final String TAG = "Utils";
    private final static String PREF_USE_VPN = "pref_vpn";
    private final static Map settings;
    static {
        settings = new HashMap();
        settings.put("httpaddr", "127.0.0.1:8787");
        settings.put("socksaddr", "127.0.0.1:9131"); 
        settings.put("udpgwaddr", "127.0.0.1:7300"); 
    }


    // update START/STOP power Lantern button
    // according to our stored preference
    public static SharedPreferences getSharedPrefs(Context context) {
        return context.getSharedPreferences(PREFS_NAME,
                Context.MODE_PRIVATE);
    }

    public static Map loadSettings(Context context, String filename) {

        InputStream in = null;
        OutputStream out = null;
        Map yamlSettings;

        try {
            Resources resources = context.getResources();
            String packageName = context.getPackageName();

            String resourceName = filename.substring(0, filename.lastIndexOf('.'));

            in = resources.openRawResource(
                    resources.getIdentifier("raw/" + resourceName,
                        "raw", packageName));

            if (in == null) {
                return settings;
            }

            Yaml yaml = new Yaml();
            yamlSettings = (Map)yaml.load(in);

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

            if (yamlSettings.get("httpaddr") != null) {
                settings.put("httpaddr", yamlSettings.get("httpaddr"));
            }
            if (yamlSettings.get("socksaddr") != null) {
                settings.put("socksaddr", yamlSettings.get("socksaddr"));
            }
        } catch (Exception e) {
            Log.e(TAG, "Unable to load settings file " + e.getMessage());
        }

        return settings;
    }

    public static void clearPreferences(Context context) {

        SharedPreferences mPrefs = getSharedPrefs(context);

        if (mPrefs != null) {
            mPrefs.edit().remove(PREF_USE_VPN).commit();
        }
    }
}
