package org.lantern.activity;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.Resources;
import android.net.Uri;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.View;
import android.widget.EditText;
import android.widget.TextView;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;

import org.lantern.LanternApp;
import org.lantern.fragment.ProgressDialogFragment;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

@EActivity(R.layout.invite_friends)
public class InviteActivity extends FragmentActivity {

    private static final String TAG = "InviteActivity";

    private ProgressDialogFragment progressFragment;

    private Context mContext;
    private SharedPreferences mPrefs = null;
    private SessionManager session;
    private String code;

    @ViewById(R.id.referral_code)
    TextView referralCode;

    @ViewById(R.id.referral_code_view)
    View referralView;

    @AfterViews
    void afterViews() {

        mContext = this.getApplicationContext();
        session = LanternApp.getSession();
        mPrefs = Utils.getSharedPrefs(mContext);

        progressFragment = ProgressDialogFragment.newInstance(R.string.progressMessage2);
    }

    @Override
    protected void onResume() {
        super.onResume();
        this.code = session.Code();
        Log.d(TAG, "referral code is " + this.code);
        referralCode.setText(this.code);
    }

    private void startProgress() {
        progressFragment.show(getSupportFragmentManager(), "progress");
    }

    private void finishProgress() {
        progressFragment.dismiss();
    }

    public void textInvite(View view) {
        Log.d(TAG, "Invite friends button clicked!");
        Resources res = getResources();
        Intent sendIntent = new Intent(Intent.ACTION_VIEW);
        sendIntent.setData(Uri.parse("sms:"));
        sendIntent.putExtra("sms_body",
                String.format(res.getString(R.string.receive_free_month), this.code));
        startActivity(sendIntent);
    }

    public void emailInvite(View view) {
        Log.d(TAG, "Continue to Pro button clicked!");

        Intent emailIntent = new Intent(Intent.ACTION_SENDTO,
                Uri.fromParts("mailto","", null));
        Resources res = getResources();
        emailIntent.putExtra(Intent.EXTRA_SUBJECT,
                res.getString(R.string.pro_invitation_subject));
        emailIntent.putExtra(Intent.EXTRA_TEXT,
            String.format(res.getString(R.string.receive_free_month), this.code));
        startActivity(Intent.createChooser(emailIntent, "Send email..."));
    }
}
