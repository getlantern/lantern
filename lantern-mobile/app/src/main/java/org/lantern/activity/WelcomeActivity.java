package org.lantern.activity;

import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.util.Log;
import android.view.View;
import android.support.v4.app.FragmentActivity;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;

import org.lantern.LanternApp;
import org.lantern.model.SessionManager;
import org.lantern.R;

@EActivity(R.layout.pro_welcome)
public class WelcomeActivity extends FragmentActivity {
    private static final String TAG = "WelcomeActivity";

    private Context mContext;
    private SessionManager session;
    private MediaPlayer mMediaPlayer;

    @AfterViews
    void afterViews() {

        mContext = this.getApplicationContext();
        session = LanternApp.getSession();

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
