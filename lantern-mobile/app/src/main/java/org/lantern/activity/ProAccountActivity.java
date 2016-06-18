package org.lantern.activity;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.res.Resources;
import android.os.Build;
import android.text.Html;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import android.support.v4.app.FragmentActivity;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;

import org.lantern.LanternApp;
import org.lantern.model.Device;
import org.lantern.model.DeviceView;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.model.MailSender;
import org.lantern.R;

@EActivity(R.layout.pro_account)
public class ProAccountActivity extends FragmentActivity {

    @ViewById
    TextView proAccountText, emailAddress, sendLogsBtn, logoutBtn, deviceName;

    @ViewById
    Button renewProBtn, changeEmailBtn;

    @ViewById
    LinearLayout deviceList;

    private static final String TAG = "ProAccountActivity";
    private SessionManager session;
    private Context context;
    private DialogInterface.OnClickListener dialogClickListener;

    @AfterViews
    void afterViews() {
        context = getApplicationContext();

        session = LanternApp.getSession();

        if (!session.deviceLinked()) {
            finish();
            return;
        }

        session.setPlanText(proAccountText, getResources());

        proAccountText.setText(String.format(getResources().getString(R.string.pro_account_expires), session.getExpiration(), 6));
        emailAddress.setText(session.Email());

        deviceName.setText(android.os.Build.MODEL);

        final ProAccountActivity proAccountActivity = this;

        dialogClickListener = new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                switch (which) {
                    case DialogInterface.BUTTON_POSITIVE:
                        //new ProRequest(proAccountActivity, true).execute("cancel");
                        break;
                    case DialogInterface.BUTTON_NEGATIVE:
                        // No button clicked
                        break;
                }
            }
        };
    }

    public void updateDeviceList() {
        for (Device device : session.getDevices()) {
            final DeviceView view = new DeviceView(this);
            String name = device.getName();
            view.name.setText(Html.fromHtml(String.format("&#8226; %s", name)));
            // set the unauthorize/X button tag to the device id
            view.unauthorize.setTag(device.getId());
            deviceList.addView(view);
        }
    }

    public void changeEmailAddress(View view) {
        Log.d(TAG, "Change email button clicked."); 
        startActivity(new Intent(this, SignInActivity.class));
    }

    public void logout(View view) {
        Log.d(TAG, "Logout button clicked.");
        session.unlinkDevice();
        startActivity(new Intent(this, LanternMainActivity_.class));
    }

    public void sendLogs(View view) {
        Log.d(TAG, "Send logs button clicked.");
        new MailSender(context, "user-send-logs").execute("support@getlantern.org");
    }

    public void renewPro(View view) {
        Log.d(TAG, "Renew Pro button clicked.");
    }

    public void unauthorizeDevice(View view) {
        Log.d(TAG, "Unauthorize device button clicked.");
        AlertDialog.Builder builder = new AlertDialog.Builder(ProAccountActivity.this);
        Resources res = getResources();
        builder.setMessage(res.getString(R.string.unauthorize_confirmation)).setPositiveButton(res.getString(R.string.yes), dialogClickListener)
            .setNegativeButton(res.getString(R.string.no), dialogClickListener).show();
    }
}

