package org.lantern.activity;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.res.Resources;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.Html;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import android.support.v4.app.FragmentActivity;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;

import org.lantern.LanternApp;
import org.lantern.model.DeviceItem;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

import go.lantern.Lantern;

@EActivity(R.layout.pro_account)
public class ProAccountActivity extends FragmentActivity implements ProResponse {

    @ViewById
    TextView proAccountText, phoneNumber, sendLogsBtn;

    @ViewById
    Button renewProBtn, changeNumberBtn;

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

        session.setPlanText(proAccountText, getResources());

        proAccountText.setText(String.format(getResources().getString(R.string.pro_account_expires), "03/15/2017", 6));
        phoneNumber.setText("+1310-484-9264");

        String[] devices = {android.os.Build.DEVICE, "Mac Desktop", "PC Desktop"};

        for (String device : devices) {
            final DeviceItem item = new DeviceItem(this);
            item.name.setText(Html.fromHtml(String.format("&#8226; %s", device)));
            deviceList.addView(item);
        }

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

    @Override
    public void onSuccess() {
        // clear user preferences now and unlink device
        session.unlinkDevice();
        // After logout, redirect to main screen
        Intent i = new Intent(this, LanternMainActivity_.class);
        i.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(i);

        finish();
    }

    @Override
    public void onError() {
        Utils.showErrorDialog(this, 
                getResources().getString(R.string.unable_to_cancel_account));
    }

    public void changePhoneNumber(View view) {
        Log.d(TAG, "Change # button clicked."); 
        startActivity(new Intent(this, SignInActivity.class));
    }

    public void sendLogs(View view) {
        Log.d(TAG, "Send logs button clicked.");
    }

    public void renewPro(View view) {
        Log.d(TAG, "Renew Pro button clicked.");
    }

    public void updateBillingInfo(View view) {

    }

    public void cancelPro(View view) {
        AlertDialog.Builder builder = new AlertDialog.Builder(ProAccountActivity.this);
        Resources res = getResources();
        builder.setMessage(res.getString(R.string.cancel_pro_confirmation)).setPositiveButton(res.getString(R.string.yes), dialogClickListener)
            .setNegativeButton(res.getString(R.string.no), dialogClickListener).show();
    }
}

