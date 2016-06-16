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
import org.lantern.model.ProResponse;
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

    private boolean signIn = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent intent = getIntent();
        if (intent != null && intent.getExtras() != null &&
                intent.getExtras().getBoolean("signIn")) {
            this.signIn = true;
            setContentView(R.layout.activity_auth_device);
        } else {
            setContentView(R.layout.activity_verify_account);
        }

        session = LanternApp.getSession();

        fragment = (UserForm) getSupportFragmentManager().findFragmentById(R.id.user_form_fragment);
    }

	@Override
	public void onResult(boolean success) {
    	if (!success) {
			onError();
        	return;
		}
		startActivity(new Intent(this, VerifyCodeActivity_.class));
	}

    public void onError() {
        Utils.showErrorDialog(this, getResources().getString(R.string.invalid_email));
    }

    public void sendResult(View view) {
		if (fragment == null) {
        	Log.e(TAG, "Missing fragment in SigninActivity");
			return;
		}
		String number = fragment.getEmailAddress();
		if (number == null) {
        	onError();
			return;
		}

		session.setPhoneNumber(number);
		String command = signIn ? "signin" : "number";
		new ProRequest(getApplicationContext(), true, this).execute(command);
    }
}
