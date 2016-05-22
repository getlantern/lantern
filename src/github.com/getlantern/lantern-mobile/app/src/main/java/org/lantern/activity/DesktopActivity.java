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
