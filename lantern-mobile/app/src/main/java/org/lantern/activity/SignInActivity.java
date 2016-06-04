package org.lantern.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.View;
import android.widget.EditText;
import android.widget.TextView;

import org.lantern.LanternApp;
import org.lantern.fragment.ProgressDialogFragment;
import org.lantern.fragment.UserForm;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

import go.lantern.Lantern;

public class SignInActivity extends FragmentActivity implements ProResponse {

    private static final String TAG = "SignInActivity";

    private EditText emailInput;
    private TextView signinList;

    private UserForm fragment;
    private SessionManager session;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent intent = getIntent();
        if (intent != null && intent.getExtras() != null &&
                intent.getExtras().getBoolean("signIn")) {
            setContentView(R.layout.activity_auth_device);
        } else {
            setContentView(R.layout.activity_verify_account);
        }

        session = LanternApp.getSession();

        fragment = (UserForm) getSupportFragmentManager().findFragmentById(R.id.user_form_fragment);
    }

    @Override
    public void onSuccess() {
        Intent intent = new Intent(this, VerifyCodeActivity_.class);
        startActivity(intent);
    }

    @Override
    public void onError() {
        Utils.showErrorDialog(this, "Invalid phone number");
    }

    public void sendResult(View view) {
        if (fragment != null) {
            String number = fragment.getPhoneNumber();
            if (number != null) {
                    session.setPhoneNumber(number);
                    new ProRequest(this, true).execute("number");
            } else {
                onError();
            }
        }
    }
}
