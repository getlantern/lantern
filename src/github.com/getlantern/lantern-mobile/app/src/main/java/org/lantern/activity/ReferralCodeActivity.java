package org.lantern.activity;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.widget.EditText;
import android.text.InputFilter;
import android.util.Log;
import android.view.View;                          
import android.widget.Button;
import android.widget.TextView;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;

import org.lantern.LanternApp;
import org.lantern.fragment.UserForm;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

import go.lantern.Lantern;

@EActivity(R.layout.activity_referral_code)
public class ReferralCodeActivity extends FragmentActivity implements ProResponse {
    private static final String TAG = "ReferralCodeActivity";

    @ViewById
    TextView continueBtn;

    @ViewById
    EditText email;

    private SessionManager session;

    private UserForm fragment;

    @AfterViews
    void afterViews() {
        session = LanternApp.getSession();

        // display continue to checkout link below send button
        continueBtn.setVisibility(View.VISIBLE);

        // make sure we use all caps to make it easier for
        // the user to enter a referral code
        email.setFilters(new InputFilter[] {new InputFilter.AllCaps()});

        fragment = (UserForm) getSupportFragmentManager().findFragmentById(R.id.user_form_fragment);
    }

    @Override
    public void onError() {
        Utils.showErrorDialog(this, "Invalid referral code");
    }

    @Override
    public void onSuccess() {
        session.setReferralApplied();
        launchCheckout();
    }

    public void sendResult(View view) {
        if (fragment != null) {
            String referral = fragment.getNumber();
            if (referral != null && !referral.equals("")) {
                session.setReferral(referral);
                new ProRequest(this).execute("referral");
            } else {
                onError();
            }
        }
    }

    public void launchCheckout() {
        Intent intent = new Intent(this, PaymentActivity_.class);
        startActivity(intent);
        finish();
    }

    public void continueBtn(View view) {
        launchCheckout();
    }
}
