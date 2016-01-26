package org.getlantern.lantern.activity;

import android.app.Fragment;
import android.app.FragmentManager;
import android.content.ComponentName;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.os.StrictMode;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.net.VpnService;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.content.pm.PackageManager;
import android.content.pm.PackageInfo;
import android.app.Activity;
import android.text.Html;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.AdapterView;
import android.widget.CompoundButton;
import android.widget.ListView;
import android.widget.Toast;
import android.widget.ToggleButton;
import android.view.MenuItem;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.support.v7.app.AppCompatActivity;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.vpn.Service;
import org.getlantern.lantern.model.UI;
import org.getlantern.lantern.sdk.Utils;
import org.getlantern.lantern.vpn.LanternVpn;
import org.getlantern.lantern.R;


public class LanternMainActivity extends AppCompatActivity implements Handler.Callback {

    private static final String TAG = "LanternMainActivity";
    private static final String PREFS_NAME = "LanternPrefs";
    private static final int CHECK_NEW_VERSION_DELAY = 10000;
    private final static int REQUEST_VPN = 7777;
    private SharedPreferences mPrefs = null;
    private BroadcastReceiver mReceiver;

    private Context context;
    private UI LanternUI;
    private Handler mHandler;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
        StrictMode.setThreadPolicy(policy);

        setContentView(R.layout.activity_lantern_main);

        // we want to use the ActionBar from the AppCompat
        // support library, but with our custom design
        // we hide the default action bar
        if (getSupportActionBar() != null) {
            getSupportActionBar().hide();
        }  

        context = getApplicationContext();
        mPrefs = Utils.getSharedPrefs(context);


        LanternUI = new UI(this, mPrefs);


        // the ACTION_SHUTDOWN intent is broadcast when the phone is
        // about to be shutdown. We register a receiver to make sure we
        // clear the preferences and switch the VpnService to the off
        // state when this happens
        IntentFilter filter = new IntentFilter(Intent.ACTION_SHUTDOWN);
        filter.addAction(Intent.ACTION_SHUTDOWN);
        filter.addAction(Intent.ACTION_USER_PRESENT);
        filter.addAction(WifiManager.SUPPLICANT_CONNECTION_CHANGE_ACTION);
        mReceiver = new LanternReceiver();
        registerReceiver(mReceiver, filter);

        if (getIntent().getBooleanExtra("EXIT", false)) {
            finish();
            return;
        }

        // setup our UI
        try {
            // configure actions to be taken whenever slider changes state
            LanternUI.setupLanternSwitch();
            LanternVpn.LanternUI = LanternUI;
        } catch (Exception e) {
            Log.d(TAG, "Got an exception " + e);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();

        // we check if mPrefs has been initialized before
        // since onCreate and onResume are always both called
        if (mPrefs != null) {
            LanternUI.setBtnStatus();
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event)  {
        if (Integer.parseInt(android.os.Build.VERSION.SDK) > 5
                && keyCode == KeyEvent.KEYCODE_BACK
                && event.getRepeatCount() == 0) {
            Log.d(TAG, "onKeyDown Called");
            onBackPressed();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }


    @Override
    public void onBackPressed() {
        Log.d(TAG, "onBackPressed Called");
        Intent setIntent = new Intent(Intent.ACTION_MAIN);
        setIntent.addCategory(Intent.CATEGORY_HOME);
        setIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(setIntent);
    }

    @Override
    protected void onDestroy() {
        try {
            unregisterReceiver(mReceiver);
            Utils.clearPreferences(this);
            stopLantern();
        } catch (Exception e) {

        }
        super.onDestroy();
    }

    // quitLantern is the side menu option and cleanyl exits the app
    public void quitLantern() {
        try {
            Log.d(TAG, "About to exit Lantern...");

            stopLantern();
            Utils.clearPreferences(this);

            // sleep for a few ms before exiting
            Thread.sleep(200);

            finish();
            moveTaskToBack(true);

        } catch (Exception e) {
            Log.e(TAG, "Got an exception when quitting Lantern " + e.getMessage());
        }
    }

    @Override
    public boolean handleMessage(Message message) {
        if (message != null) {
            //Toast.makeText(this, message.what, Toast.LENGTH_SHORT).show();
        }
        return true;
    }

    public void sendDesktopVersion(View view) {
        if (LanternUI != null) {
            LanternUI.sendDesktopVersion(view);
        }
    }

    // isNetworkAvailable checks whether or not we are connected to
    // the Internet; if no connection is available, the toggle
    // switch is inactive
    public boolean isNetworkAvailable() {
        final Context context = this;
        final ConnectivityManager connectivityManager = ((ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE));
        return connectivityManager.getActiveNetworkInfo() != null && connectivityManager.getActiveNetworkInfo().isConnected();
    }

    // Make a VPN connection from the client
    // We should only have one active VPN connection per client
    private void startVpnService ()
    {
        Intent intent = VpnService.prepare(this);
        if (intent != null) {
            Log.w(TAG,"Requesting VPN connection");
            startActivityForResult(intent, REQUEST_VPN);
        } else {
            Log.d(TAG, "VPN enabled, starting Lantern...");
            LanternUI.toggleSwitch(true);
            sendIntentToService();
        }
    }


    // Prompt the user to enable full-device VPN mode
    public void enableVPN() {
        Log.d(TAG, "Load VPN configuration");

        try {
            startVpnService();
        } catch (Exception e) {
            Log.d(TAG, "Could not establish VPN connection: " + e.getMessage());
        }
    }

    @Override
    protected void onActivityResult(int request, int response, Intent data) {
        super.onActivityResult(request, response, data);

        if (request == REQUEST_VPN) {
            if (response != RESULT_OK) {
                // no permission given to open
                // VPN connection; return to off state
                LanternUI.toggleSwitch(false);
            } else {
                LanternUI.toggleSwitch(true);

                Handler h = new Handler();
                h.postDelayed(new Runnable () {

                    public void run ()
                    {
                        sendIntentToService();
                    }
                }, 1000);
            }
        }
    }

    private void sendIntentToService() {
        startService(new Intent(this, Service.class));
    }

    public void restart(final Context context, final Intent intent) {
        if (LanternUI.useVpn()) {
            Log.d(TAG, "Restarting Lantern...");
            Service.IsRunning = false;

            final LanternMainActivity activity = this;
            Handler h = new Handler();
            h.postDelayed(new Runnable () {
                public void run() {
                    enableVPN();
                }
            }, 1000);
        }
    }

    public void stopLantern() {
        Service.IsRunning = false;
        Utils.clearPreferences(this);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Pass the event to ActionBarDrawerToggle
        // If it returns true, then it has handled
        // the nav drawer indicator touch event
        if (LanternUI != null &&
                LanternUI.optionSelected(item)) {
            return true;
        }

        // Handle your other action bar items...
        return super.onOptionsItemSelected(item);
    }

    @Override
    protected void onPostCreate(Bundle savedInstanceState) {
        super.onPostCreate(savedInstanceState);
        if (LanternUI != null) {
            LanternUI.syncState();
        }
    }

    public class LanternReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            // whenever the device is powered off or the app
            // abruptly closed, we want to clear user preferences
            if (action.equals(Intent.ACTION_SHUTDOWN)) {
                Utils.clearPreferences(context);
            } else if (action.equals(Intent.ACTION_USER_PRESENT)) {
                //restart(context, intent);
            }
        }
    }

    public void checkNewVersion() {
        try {
            final Context context = this;

            String latestVersion = "test";

            PackageInfo pInfo = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);

            String version = pInfo.versionName;
            Log.d(TAG, "Current version of app is " + version);

            if (latestVersion != null && !latestVersion.equals(version)) {
                // Latest version of FireTweet and the version currently running differ
                // display the update view
                final Intent intent = new Intent(context, UpdaterActivity.class);
                context.startActivity(intent);
            }

        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "Error fetching package information");
        }
    }
}
