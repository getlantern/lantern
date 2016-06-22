package org.lantern.activity;

import android.app.AlertDialog;
import android.app.ProgressDialog;
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

import go.lantern.Lantern;

@EActivity(R.layout.pro_account)
public class ProAccountActivity extends FragmentActivity {

    @ViewById
    TextView proAccountText, freeMonthsText, emailAddress, sendLogsBtn, logoutBtn, deviceName;

    @ViewById
    Button renewProBtn;

    @ViewById
    LinearLayout deviceList;

    private static final String TAG = "ProAccountActivity";
    private SessionManager session;
    private ProgressDialog dialog;
    private String toRemoveDeviceId;

    @AfterViews
    void afterViews() {
        dialog = new ProgressDialog(ProAccountActivity.this);

        session = LanternApp.getSession();

        if (!session.deviceLinked()) {
            finish();
            return;
        }

        session.setPlanText(proAccountText, getResources());

        proAccountText.setText(String.format(getResources().getString(R.string.pro_account_expires), session.getExpiration()));

        int numFreeMonths = session.getNumFreeMonths();
        if (numFreeMonths > 0) {
            freeMonthsText.setVisibility(View.VISIBLE);
            freeMonthsText.setText(String.format(getResources().getString(R.string.includes_free_months), numFreeMonths));
        }

        updateDeviceList();

        emailAddress.setText(session.Email());

        deviceName.setText(android.os.Build.MODEL);

        final ProAccountActivity proAccountActivity = this;
    }

    public void updateDeviceList() {
        for (Device device : session.getDevices().values()) {
            final DeviceView view = new DeviceView(this);
            String name = device.getName();
            view.name.setText(Html.fromHtml(String.format("&#8226; %s", name)));
            // set the unauthorize/X button tag to the device id
            view.unauthorize.setTag(device.getId());
            deviceList.addView(view);
        }
    }

    public void removeDevice(View view) {
        String deviceId = (String)view.getTag();
        if (deviceId == null) {
            return;
        }
        session.removeDevice(deviceId);
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
        new MailSender(ProAccountActivity.this, "user-send-logs").execute("support@getlantern.org");
    }

    public void renewPro(View view) {
        Log.d(TAG, "Renew Pro button clicked.");
        startActivity(new Intent(this, PlansActivity_.class));
    }

    public void unauthorizeDevice(View view) {
        Log.d(TAG, "Unauthorize device button clicked.");
       	final String deviceId = (String)view.getTag();
        if (deviceId == null) {
            Log.e(TAG, "Error trying to get tag for device item; cannot unauthorize device");
            return;
        }

        AlertDialog.Builder builder = new AlertDialog.Builder(ProAccountActivity.this);
        Resources res = getResources();

		final boolean shouldProxy = session.shouldProxy();

		DialogInterface.OnClickListener dialogClickListener = new DialogInterface.OnClickListener() {
			@Override
			public void onClick(DialogInterface dialog, int which) {
				switch (which) {
					case DialogInterface.BUTTON_POSITIVE:
						boolean success = Lantern.RemoveDevice(shouldProxy, deviceId, session);
						dialog.dismiss();
						break;
					case DialogInterface.BUTTON_NEGATIVE:
						dialog.cancel();
						// No button clicked
						break;
				}
			}
		};

        builder.setMessage(res.getString(R.string.unauthorize_confirmation));
		builder.setPositiveButton(res.getString(R.string.yes), dialogClickListener);
        builder.setNegativeButton(res.getString(R.string.no), dialogClickListener);
		builder.show();
    }
}

