package org.getlantern.lantern.activity;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;

import org.getlantern.lantern.R;

public class InviteActivity extends Activity {

    private static final String TAG = "InviteActivity";

    private EditText emailInput;
    private Button getCodeBtn;
    private View getCodeView;
    private View referralView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.invite_friends);

        getCodeView = findViewById(R.id.get_code_view);
        referralView = findViewById(R.id.referral_code_view);

        this.emailInput = (EditText)findViewById(R.id.proEmailAddress);
        this.getCodeBtn = (Button)findViewById(R.id.getCodeBtn);

        this.getCodeBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "Get code button pressed");
                referralView.setVisibility(View.VISIBLE);
                getCodeView.setVisibility(View.INVISIBLE);
            }
        });

        ImageView backBtn = (ImageView)findViewById(R.id.inviteAvatar);

        backBtn.setOnClickListener(new View.OnClickListener() {

            @Override
            public void onClick(View v) {
                Log.d(TAG, "Back button pressed");
                finish();
            }
        });

    }

    public void getCode(View view) {
        final String email = emailInput.getText().toString();

    }

    public void textInvite(View view) {
        Log.d(TAG, "Invite friends button clicked!");
    }

    public void emailInvite(View view) {
        Log.d(TAG, "Continue to Pro button clicked!");
    }
}
