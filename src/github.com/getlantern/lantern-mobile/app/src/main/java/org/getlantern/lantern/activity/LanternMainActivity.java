package org.getlantern.lantern.activity;

import android.content.Intent;
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
    private Button powerLantern;
    private boolean mLanternRunning = false;
    private Handler mHandler;
    private boolean resumeHasRun = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_lantern_main);

        powerLantern = (Button)findViewById(R.id.powerLantern);
        setupLanternSwitch();
    }

    @Override
    protected void onResume() {
        super.onResume();
    }

    // START/STOP button to enable full-device VPN functionality
    private void setupLanternSwitch() {

        // START/STOP button to enable full-device VPN functionality
        powerLantern.setOnClickListener(new OnClickListener() {

            @Override
            public void onClick(View v) {
                Button b = (Button) v;
                if (!mLanternRunning) {
                    enableVPN();
                    b.setText(LanternConfig.STOP_BUTTON_TEXT);
                } else {
                    stopLantern();
                    b.setText(LanternConfig.START_BUTTON_TEXT);
                }

                mLanternRunning = !mLanternRunning;
            }
        });
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
