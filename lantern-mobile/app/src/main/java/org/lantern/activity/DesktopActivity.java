package org.lantern.activity;

import android.os.AsyncTask;
import android.os.Build;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.support.v4.app.FragmentActivity;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;

import org.lantern.model.MailSender;
import org.lantern.model.Utils;
import org.lantern.R;

@EActivity(R.layout.desktop_option)
public class DesktopActivity extends FragmentActivity {

    private static final String TAG = "DesktopActivity";

    @ViewById
    Button sendBtn;

    @ViewById
    EditText emailInput;

    @ViewById
    View separator;

    public void sendDesktopVersion(View view) {
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
        MailSender mailSender = new MailSender(DesktopActivity.this, "download-link-from-lantern-website");
        if (Build.VERSION.SDK_INT>=Build.VERSION_CODES.HONEYCOMB)
            mailSender.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, email);
        else
            mailSender.execute(email);

        // revert send button, separator back to defaults
        sendBtn.setBackgroundResource(R.drawable.send_btn); 
        sendBtn.setClickable(false);
        separator.setBackgroundResource(R.color.edittext_color);
        emailInput.setText("");
    }
}
