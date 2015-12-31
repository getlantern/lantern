package org.getlantern.lantern.activity;

import android.app.Activity;
import android.os.Bundle;
import android.text.Html;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;

import org.getlantern.lantern.R;

public class SignInActivity extends Activity {

    private static final String TAG = "SignInActivity";

    private TextView signinList;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.sign_in);

        signinList = (TextView)findViewById(R.id.sign_in_list);
        signinList.setText(Html.fromHtml(getResources().getString(R.string.sign_in_list)));

        ImageView backBtn = (ImageView)findViewById(R.id.signinAvatar);
        backBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.d(TAG, "Back button pressed");
                finish();
            }
        });
    }

    public void sendLink(View view) {
        Log.d(TAG, "Send link button clicked");
    }

}
