package org.getlantern.lantern.activity;

import android.app.Activity;
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

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.getlantern.lantern.model.MailSender;
import org.getlantern.lantern.sdk.Utils;
import org.getlantern.lantern.R;

public class DesktopActivity extends Activity {

    private static final String TAG = "DesktopActivity";

    private Button sendBtn;
    private EditText emailInput;
    private View separator;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.desktop_option);

        Log.d(TAG, "Desktop activity created...");

        ImageView backBtn = (ImageView)findViewById(R.id.desktopAvatar);
        backBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });

        emailInput = (EditText)findViewById(R.id.sendEmail);
        sendBtn = (Button)findViewById(R.id.sendBtn);
        separator = (View)findViewById(R.id.separator);
       
        configureEmailInput();
    }

    public void sendDesktopVersion(View view) {
        final MailSender sender = new MailSender();
        final String email = emailInput.getText().toString();

        final DesktopActivity activity = this;

        Log.d(TAG, "Sending Lantern Desktop to " + email);

        AsyncTask<Void, Void, Void> asyncTask = new AsyncTask<Void, Void, Void>() {
            @Override 
            public Void doInBackground(Void... arg) {
                String msg;

                try {
                    Log.d(TAG, "Calling send mail...");
                    sender.sendMail(email);
                    Log.d(TAG, "Successfully called send mail");
                    msg = getResources().getString(R.string.success_email);
                } catch (Exception e) {
                    Log.e(TAG, e.getMessage(), e);     
                    msg = getResources().getString(R.string.error_email);
                }

                Utils.showAlertDialog(activity, "Lantern", msg);
                return null;
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

    private void configureEmailInput() {

        emailInput.addTextChangedListener(new TextWatcher() {
            public void afterTextChanged(Editable s) {
                if (s.length() == 0) {
                    separator.setBackgroundResource(R.color.edittext_color);
                } else {
                    separator.setBackgroundResource(R.color.blue_color);
                }
            }

            public void beforeTextChanged(CharSequence s, int start,
                    int count, int after) {
            }

            public void onTextChanged(CharSequence s, int start,
                    int before, int count) {
                if (isEmailValid(s.toString())) {
                    sendBtn.setBackgroundResource(R.drawable.send_btn_blue);
                    sendBtn.setClickable(true);
                } else {
                    sendBtn.setBackgroundResource(R.drawable.send_btn);
                    sendBtn.setClickable(false);
                }
            }

        });
    }

    private static boolean isEmailValid(String email) {
        boolean isValid = false;

        String expression = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{2,4}$";
        CharSequence inputStr = email;

        Pattern pattern = Pattern.compile(expression, Pattern.CASE_INSENSITIVE);
        Matcher matcher = pattern.matcher(inputStr);
        if (matcher.matches()) {
            isValid = true;
        }
        return isValid;
    }

 

}
