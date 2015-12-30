package org.getlantern.lantern.activity;

import android.app.Activity;
import android.content.Intent;
import android.net.VpnService;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;

import org.getlantern.lantern.model.UI;
import org.getlantern.lantern.config.LanternConfig;
import org.getlantern.lantern.vpn.Service;
 

public class PromptVpnActivity extends Activity {

    private static final String TAG = "PromptVpnActivity";
    private final static int REQUEST_VPN = 7777;
    private	Intent intent = null;

    public static UI LanternUI;

    @Override
    public void onCreate( Bundle icicle ) {
        super.onCreate( icicle );

        Log.d(TAG, "Prompting user to start Lantern VPN");

        intent = VpnService.prepare(this);

        startVpnService();

    }

    // Make a VPN connection from the client
    // We should only have one active VPN connection per client
    private void startVpnService ()
    {
        if (intent != null) {
            Log.w(TAG,"Requesting VPN connection");
            startActivityForResult(intent,REQUEST_VPN);
        } else {
            Log.d(TAG, "VPN enabled, starting Lantern...");

            LanternUI.toggleSwitch(true);

            Handler h = new Handler();
            h.postDelayed(new Runnable () {

                public void run ()
                {
                    sendIntentToService();
                    finish();
                }
            }, 1000);

        }
    }

    @Override
    protected void onActivityResult(int request, int response, Intent data) {
        super.onActivityResult(request, response, data);

        if (request == REQUEST_VPN) {
            if (response != RESULT_OK) {
                LanternUI.toggleSwitch(false);
                finish();
                return;
            }
    
            LanternUI.toggleSwitch(true);

            Handler h = new Handler();
            h.postDelayed(new Runnable () {

                public void run ()
                {
                    sendIntentToService();
                    finish();
                }
            }, 1000);
        }
    }


    private void sendIntentToService() {
        startService(new Intent(this, Service.class));
    }

}
