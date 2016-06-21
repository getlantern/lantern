package org.lantern.activity;

import android.content.Intent;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.View;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.Extra;
import org.androidannotations.annotations.FragmentById;

import org.lantern.LanternApp;
import org.lantern.fragment.UserForm;
import org.lantern.model.ProRequest;
import org.lantern.model.ProResponse;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

@EActivity(R.layout.activity_verify_code)
public class VerifyCodeActivity extends FragmentActivity implements ProResponse {
    private static final String TAG = "VerifyCodeActivity";

    private SessionManager session;

    @Extra("signIn")
    boolean signIn = false;

    @FragmentById(R.id.user_form_fragment)
    UserForm fragment;

    @AfterViews
    void afterViews() {
        session = LanternApp.getSession();
    }

    @Override
    public void onResult(boolean success) {
        if (!success) {
            onError();
            return;
        }

        session.linkDevice();

        Intent intent;                                            
        if (signIn) {
            session.setIsProUser(true);
            intent = new Intent(this, LanternMainActivity_.class);
        } else {
            intent = new Intent(this, ProAccountActivity_.class);
        }

        new ProRequest(VerifyCodeActivity.this, false, null).execute("userdata");


        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();   
    }

    public void onError() {
        Utils.showErrorDialog(this,
            getResources().getString(R.string.invalid_verification_code));
    }

    public void sendResult(View view) {
        if (fragment == null) {
            Log.e(TAG, "Missing fragment in VerifyCodeActivity");
            return;
        }

        String codeStr = fragment.getUserInput();
        if (codeStr == null) {
            onError();
            return;
        }

        long code = Long.parseLong(codeStr);
        session.setVerifyCode(code);
        new ProRequest(VerifyCodeActivity.this, true, this).execute("code");
    }
}
 
