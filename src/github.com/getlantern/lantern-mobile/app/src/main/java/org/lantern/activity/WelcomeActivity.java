package org.lantern.activity;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.View;                          

import org.lantern.LanternApp;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.R;

import go.lantern.Lantern;

public class WelcomeActivity extends Activity {
    private static final String TAG = "WelcomeActivity";

    public static LanternMainActivity mainActivity;

    private String stripeToken, stripeEmail, plan;
    private Context mContext;
    private SessionManager session;
    private MediaPlayer mMediaPlayer;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.pro_welcome);

        mContext = this.getApplicationContext();
        session = LanternApp.getSession();

        Intent intent = getIntent();
        Uri data = intent.getData();

        if (data != null && (stripeToken == null || stripeToken.equals(""))) {
            stripeToken = data.getQueryParameter("stripeToken");
            stripeEmail = data.getQueryParameter("stripeEmail");  
            plan = data.getQueryParameter("plan");
        }

        if (stripeToken != "" && stripeEmail != "") {
            Log.d(TAG, "Stripe token is " + stripeToken +
                    "; email is " + stripeEmail + " ;" + plan);

            session.setProUser(stripeEmail, stripeToken,
                    plan);
            //new ProRequest(this).execute("purchase");
        }

        playWelcomeSound();

        mainActivity.setupSideMenu();
    }

    public void inviteFriends(View view) {
        Log.d(TAG, "Invite friends button clicked!");
        startActivity(new Intent(this, InviteActivity_.class));
    }

    public void continueToPro(View view) {
        Log.d(TAG, "Continue to Pro button clicked!");
        startActivity(new Intent(this, LanternMainActivity_.class));
    }

    public void playWelcomeSound() {
        mMediaPlayer = MediaPlayer.create(this, R.raw.welcome);
        mMediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);
        mMediaPlayer.setLooping(false);
        mMediaPlayer.start();
    }
}
