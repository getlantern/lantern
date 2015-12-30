package org.getlantern.lantern.activity;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;                          

import org.getlantern.lantern.R;

public class ProActivity extends Activity {
    private static final String TAG = "ProActivity";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.pro_welcome);
    }

    public void inviteFriends(View view) {
        Log.d(TAG, "Invite friends button clicked!");
    }

    public void continueToPro(View view) {
        Log.d(TAG, "Continue to Pro button clicked!");
    }
}
