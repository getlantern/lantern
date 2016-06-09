package org.getlantern.lantern.activity;

import android.app.Activity;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.support.v4.app.FragmentActivity;

import org.androidannotations.annotations.AfterTextChange;
import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.Click;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.TextChange;
import org.androidannotations.annotations.ViewById;

import org.getlantern.lantern.model.MailSender;
import org.getlantern.lantern.model.Utils;
import org.getlantern.lantern.R;

@EActivity(R.layout.desktop_option)
public class DesktopActivity extends FragmentActivity {

    private static final String TAG = "DesktopActivity";

    @ViewById
    ImageView backBtn;

    @ViewById
    Button sendBtn;

    @ViewById
    EditText emailInput;

    @ViewById
    View separator;

    @TextChange(R.id.emailInput)
    void emailInputTextChanged(CharSequence s, int start, int before, int count) {
        if (Utils.isEmailValid(s.toString())) {
            sendBtn.setBackgroundResource(R.drawable.send_btn_blue);
            sendBtn.setClickable(true);
        } else {
            sendBtn.setBackgroundResource(R.drawable.send_btn);
            sendBtn.setClickable(false);
        }
    }

    @AfterTextChange(R.id.emailInput)
    void emailInputAfterTextChanged(Editable s) {
        if (s.length() == 0) {
            separator.setBackgroundResource(R.color.edittext_color);
        } else {
            separator.setBackgroundResource(R.color.blue_color);
        }
    }

    @Click(R.id.backBtn)
    void returnHome() {
        startActivity(new Intent(this, LanternMainActivity_.class));
    }

    public void sendDesktopVersion(View view) {
        final MailSender sender = new MailSender();
        final String email = emailInput.getText().toString();
        Log.d(TAG, "Sending Lantern Desktop to " + email);

        if (!Utils.isEmailValid(email)) {
            Utils.showErrorDialog(this, 
                    getResources().getString(R.string.invalid_email));
            return;
        }

        if (!Utils.isNetworkAvailable(this)) {
            Utils.showErrorDialog(this, 
                    getResources().getString(R.string.no_internet_connection));
            return;
        }

        final DesktopActivity activity = this;

        Log.d(TAG, "Sending Lantern Desktop to " + email);

        AsyncTask<Void, Void, Boolean> asyncTask = new AsyncTask<Void, Void, Boolean>() {
            @Override 
            public Boolean doInBackground(Void... arg) {

                try {
                    Log.d(TAG, "Calling send mail...");
                    sender.sendMail(email);
                    Log.d(TAG, "Successfully called send mail");
                    return true;
                } catch (Exception e) {
                    Log.e(TAG, e.getMessage(), e);     
                }
                return false;
            }

            @Override
            protected void onPostExecute(Boolean success) {
                super.onPostExecute(success);
                String msg;
                if (success) {
                    msg = getResources().getString(R.string.success_email);
                } else {
                    msg = getResources().getString(R.string.error_email);
                }
                Utils.showAlertDialog(activity, "Lantern", msg);
            }
        };

        if (Build.VERSION.SDK_INT >= 11) {
            asyncTask.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
        }
        else {
            asyncTask.execute();
        }

        // revert send button, separator back to defaults
        sendBtn.setBackgroundResource(R.drawable.send_btn);
        sendBtn.setClickable(false);
        separator.setBackgroundResource(R.color.edittext_color);
        emailInput.setText("");
    }
}
