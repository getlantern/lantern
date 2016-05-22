package org.lantern.activity;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Bundle;
import android.os.Message;
import android.support.v4.app.FragmentActivity;
import android.text.Html;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.webkit.ConsoleMessage;
import android.webkit.SslErrorHandler;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;
import org.androidannotations.annotations.res.StringArrayRes;

import java.text.NumberFormat;
import java.util.Locale;

import org.lantern.LanternApp;
import org.lantern.activity.PaymentActivity;
import org.lantern.activity.CheckoutActivity;
import org.lantern.model.FeatureUi;
import org.lantern.model.SessionManager;
import org.lantern.R;

@EActivity(R.layout.pro_plans)
public class PlansActivity extends FragmentActivity {

    private static final String TAG = "PlansActivity";
    private static final String mCheckoutUrl = 
        "https://s3.amazonaws.com/lantern-android/checkout.html?amount=%d";
    private static final boolean useAlipay = false;

    private static final NumberFormat currencyFormatter = 
        NumberFormat.getCurrencyInstance(new Locale("en", "US"));

    private static final Integer monthCost = 799;
    private static final Integer yearCost = 499 * 12;

    private SessionManager session;

    @StringArrayRes(R.array.pro_features)
    String[] proFeaturesList;

    @ViewById
    Button monthBtn, yearBtn;

    @ViewById
    LinearLayout leftFeatures, rightFeatures;

    @ViewById(R.id.plans_view)
    LinearLayout plansView;

    @AfterViews
    void afterViews() {
        session = LanternApp.getSession();

        int i = 0;
        int mid = proFeaturesList.length/2;
        for (String proFeature : proFeaturesList) {
            final FeatureUi feature = new FeatureUi(this);
            feature.text.setText(proFeature);

            if (i < mid) 
                leftFeatures.addView(feature);
            else
                rightFeatures.addView(feature);

            i++;
        }

        monthBtn.setTag(monthCost);
        yearBtn.setTag(yearCost);

        plansView.bringToFront();
    }

    public void selectPlan(View view) {
        Integer amount = (Integer)view.getTag();

		Log.d(TAG, "Plan selected: " + amount);

        Intent intent;

        if (useAlipay) {
            Log.d(TAG, "Chinese user detected; opening Alipay by default");
            intent = new Intent(Intent.ACTION_VIEW);
            intent.setData(Uri.parse(String.format(mCheckoutUrl, amount)));

        } else {
            intent = new Intent(this, PaymentActivity.class);

            String amountStr = currencyFormatter.format(amount / 100.0);
            SessionManager.chargeAmount = (Integer)amount;
            SessionManager.chargeStr = amountStr;
        }

        // make sure user links device before proceeding
        if (!session.deviceLinked()) {
            return;
        }

        if (!session.isReferralApplied()) {
            Intent i = new Intent(this,
                    ReferralCodeActivity_.class);
            // close all previous activities
            i.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
            i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(i);
        } else {
            startActivity(intent);
        }
    }
}  
