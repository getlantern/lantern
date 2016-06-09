package org.lantern.activity;

import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.support.v4.app.FragmentActivity;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;

import org.lantern.LanternApp;
import org.lantern.model.SessionManager;
import org.lantern.R;

@EActivity(R.layout.pro_welcome)
public class WelcomeActivity extends FragmentActivity {
    private static final String TAG = "WelcomeActivity";

    private Context mContext;
    private SessionManager session;
    private MediaPlayer mMediaPlayer;

    @ViewById
    LinearLayout container;

    @ViewById
    TextView header;

    @AfterViews
    void afterViews() {

        mContext = this.getApplicationContext();
        session = LanternApp.getSession();

        // we re-use the titlebar component here
        // but center the label since there is no
        // back button on this screen
        header.setPadding(0, 0, 0, 0);
        container.setGravity(Gravity.CENTER);

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
