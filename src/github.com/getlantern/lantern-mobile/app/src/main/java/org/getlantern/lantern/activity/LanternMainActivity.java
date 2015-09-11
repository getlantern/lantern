package org.getlantern.lantern.activity;

import android.content.Intent;
import android.content.Context;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.preference.PreferenceManager;
import android.content.SharedPreferences;
import android.support.v7.app.ActionBarActivity;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;

import android.net.VpnService;

import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.R;
import org.getlantern.lantern.service.LanternVpn;


public class LanternMainActivity extends ActionBarActivity implements Handler.Callback {

    private static final String TAG = "LanternMainActivity";
    private static final String PREFS_NAME = "LanternPrefs";
    private SharedPreferences mPrefs = null;

    private Button powerLantern;
    private Handler mHandler;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        mPrefs = getSharedPrefs(getApplicationContext());

        setContentView(R.layout.activity_lantern_main);

        powerLantern = (Button)findViewById(R.id.powerLantern);
        setupLanternSwitch();
    }

    @Override
    protected void onResume() {
        super.onResume();

        // we check if mPrefs has been initialized before
        // since onCreate and onResume are always both called
        if (mPrefs != null) {
            setBtnStatus();
        }
    }

    // START/STOP button to enable full-device VPN functionality
    private void setupLanternSwitch() {

        setBtnStatus();

        // START/STOP button to enable full-device VPN functionality
        powerLantern.setOnClickListener(new OnClickListener() {
            @Override
            public void onClick(View v) {
                Button b = (Button) v;
                boolean useVpn;

                if (b.getText() == LanternConfig.START_BUTTON_TEXT) {
                    enableVPN();
                    useVpn = true;
                } else {
                    stopLantern();
                    useVpn = false;
                }

                // update button text after we've clicked on it
                b.setText(useVpn ? LanternConfig.STOP_BUTTON_TEXT : LanternConfig.START_BUTTON_TEXT);
                // store the updated preference 
                mPrefs.edit().putBoolean(LanternConfig.PREF_USE_VPN, useVpn).commit();

            }
        });
    } 

    // update START/STOP power Lantern button
    // according to our stored preference
    public void setBtnStatus() {
        boolean useVPN = useVpn();
        if (!useVPN) {
            powerLantern.setText(LanternConfig.START_BUTTON_TEXT);
        } else {
            powerLantern.setText(LanternConfig.STOP_BUTTON_TEXT);
        }
    }

    public SharedPreferences getSharedPrefs(Context context) {
        return context.getSharedPreferences(PREFS_NAME,
                Context.MODE_PRIVATE);
    }

    public boolean useVpn() {
        return mPrefs.getBoolean(LanternConfig.PREF_USE_VPN, false);
    }

    @Override
    public boolean handleMessage(Message message) {
        if (message != null) {
            //Toast.makeText(this, message.what, Toast.LENGTH_SHORT).show();
        }
        return true;
    }

    // Prompt the user to enable full-device VPN mode
    protected void enableVPN() {
        Log.d(TAG, "Load VPN configuration");
        Intent intent = new Intent(LanternMainActivity.this, PromptVpnActivity.class);
        if (intent != null) {
            startActivity(intent);
        }
    }

    protected void stopLantern() {
        Log.d(TAG, "Stopping Lantern...");
        try {
            Intent service = new Intent(LanternMainActivity.this, LanternVpn.class);
            service.setAction(LanternConfig.DISABLE_VPN);
            startService(service);
        } catch (Exception e) {
            Log.d(TAG, "Got an exception trying to stop Lantern: " + e);
        }
    }
}
