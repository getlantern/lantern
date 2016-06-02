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
import android.support.v4.app.FragmentActivity;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;
import org.androidannotations.annotations.ItemClick;

import org.lantern.LanternApp;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

import go.lantern.Lantern;

@EActivity(R.layout.pro_welcome)
public class WelcomeActivity extends FragmentActivity implements ProResponse {
    private static final String TAG = "WelcomeActivity";

    private String stripeToken, stripeEmail, plan;
    private Context mContext;
    private SessionManager session;
    private MediaPlayer mMediaPlayer;

    @AfterViews
    void afterViews() {

        mContext = this.getApplicationContext();
        session = LanternApp.getSession();

        Intent intent = getIntent();
        Uri data = intent.getData();

        if (data != null && (stripeToken == null || stripeToken.equals(""))) {
            stripeToken = data.getQueryParameter("stripeToken");
            stripeEmail = data.getQueryParameter("stripeEmail");  
            plan = data.getQueryParameter("plan");
        }

        if (stripeToken != null && !"".equals(stripeToken)) {
            Log.d(TAG, "Stripe token is " + stripeToken +
                    "; email is " + stripeEmail + " ;" + plan);

            session.setProUser(stripeEmail, stripeToken,
                    plan);
        } else {
            playWelcomeSound();
        }
    }

    @Override
    public void onError() {
        Utils.showErrorDialog(this, 
                getResources().getString(R.string.could_not_complete_purchase));
    }

    @Override
    public void onSuccess() {
        playWelcomeSound();
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
        Log.d(TAG, "Playing Pro welcome sound!");
        mMediaPlayer = MediaPlayer.create(this, R.raw.welcome);
        mMediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);
        mMediaPlayer.setLooping(false);
        mMediaPlayer.start();
    }
}
