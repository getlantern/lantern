package org.lantern.activity;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.View;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;

import org.lantern.LanternApp;
import org.lantern.fragment.ProgressDialogFragment;
import org.lantern.fragment.UserForm;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

import go.lantern.Lantern;

@EActivity(R.layout.activity_verify_code)
public class VerifyCodeActivity extends FragmentActivity implements ProResponse {
    private static final String TAG = "VerifyCodeActivity";

    private SessionManager session;
    private UserForm fragment;

    @AfterViews
    void afterViews() {
        session = LanternApp.getSession();
        fragment = (UserForm) getSupportFragmentManager().findFragmentById(R.id.user_form_fragment);
    }

    @Override
    public void onError() {
        Utils.showErrorDialog(this,
                getResources().getString(R.string.invalid_verification_code));
    }

    @Override
    public void onSuccess() {
        session.linkDevice();

        if (PaymentActivity.plan != null) {
            if (!session.isReferralApplied()) {
                Intent i = new Intent(this,
                        ReferralCodeActivity_.class);
                // close all previous activities
                i.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
                i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(i);
                finish();
                return;
            }
        }

        Intent intent;
        if (session.isProUser()) {
            intent = new Intent(this, LanternMainActivity_.class);
        } else {
            intent = new Intent(this, PaymentActivity_.class);
        }
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }

    public void sendResult(View view) {
        if (fragment != null) {
            String code = fragment.getNumber();
            if (code != null) {
                session.setVerifyCode(code);
                new ProRequest(this, true).execute("code");
            } else {
                onError();
            }
        }
    }
}
 
