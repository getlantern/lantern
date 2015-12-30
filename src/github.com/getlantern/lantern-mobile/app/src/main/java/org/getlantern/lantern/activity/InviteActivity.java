package org.getlantern.lantern.activity;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageView;

import org.getlantern.lantern.R;

public class InviteActivity extends Activity {

    private static final String TAG = "InviteActivity";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.invite_friends);

        ImageView backBtn = (ImageView)findViewById(R.id.inviteAvatar);

        backBtn.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                Log.d(TAG, "Back button pressed");
                finish();
            }
        });
    }

    public void textInvite(View view) {
        Log.d(TAG, "Invite friends button clicked!");
    }

    public void emailInvite(View view) {
        Log.d(TAG, "Continue to Pro button clicked!");
    }
}
