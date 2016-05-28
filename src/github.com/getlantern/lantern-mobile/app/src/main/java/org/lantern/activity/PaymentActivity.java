package org.lantern.activity;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.net.Uri;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.webkit.ConsoleMessage;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentActivity;

import com.stripe.android.Stripe;
import com.stripe.android.TokenCallback;
import com.stripe.android.model.Card;
import com.stripe.android.model.Token;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.FragmentById;
import org.androidannotations.annotations.ViewById;

import org.lantern.LanternApp;
import org.lantern.fragment.ErrorDialogFragment;
import org.lantern.fragment.PaymentFormFragment;
import org.lantern.fragment.ProgressDialogFragment;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

import java.text.NumberFormat;
import java.util.Locale;

import com.thefinestartist.finestwebview.FinestWebView;

import info.hoang8f.android.segmented.SegmentedGroup;

@EActivity(R.layout.checkout)
public class PaymentActivity extends FragmentActivity implements ProResponse, View.OnClickListener {

    private static final String TAG = "PaymentActivity";
    private static final String mCheckoutUrl = "https://s3.amazonaws.com/lantern-android/checkout.html?plan=%s";

    private static final NumberFormat currencyFormatter = 
        NumberFormat.getCurrencyInstance(new Locale("en", "US"));

    private SessionManager session;
    private Context mContext;

    private ProgressDialogFragment progressFragment;

    public static String plan;

    private static final Integer oneYearCost = 2000;
    private static final Integer twoYearCost = 3600;

    private int chargeAmount = oneYearCost;

    @FragmentById(R.id.payment_form)
    PaymentFormFragment paymentForm;

    @ViewById
    TextView chargeAmountView;

    @ViewById
    View cardView;

    @ViewById
    WebView webView;

    @ViewById
    Button checkoutBtn, cardBtn, alipayBtn;

    @ViewById(R.id.email)
    EditText emailInput;

    @ViewById(R.id.segmented2)
    SegmentedGroup segmented; 

    @AfterViews
    void afterViews() {
        mContext = this.getApplicationContext();
        session = LanternApp.getSession();

        segmented.setTintColor(getResources().getColor(R.color.pink));

        cardBtn.setOnClickListener(this);
        alipayBtn.setOnClickListener(this);

        Intent intent = getIntent();

        if (plan != null) {
            if (plan.equals(SessionManager.ONE_YEAR_PLAN)) {
                chargeAmount = oneYearCost;
            } else {
                chargeAmount = twoYearCost;
            }
        }
        chargeAmountView.setText(currencyFormatter.format(chargeAmount / 100.0));

        checkoutBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                submitCard();
            }
        });

        progressFragment = ProgressDialogFragment.newInstance(R.string.progressMessage);
    }

    @Override
    public void onClick(View v) {
        Log.d(TAG, "onclick called...");
        switch (v.getId()) {
            case R.id.alipayBtn:
                Log.d(TAG, "Alipay button pressed");
                Intent intent = new Intent(Intent.ACTION_VIEW);
                String plan;
                if (chargeAmount == 799) {
                    plan = "Lantern Pro 1 Year";
                } else {
                    plan = "year";
                }
                loadWebView(plan);
                //intent.setData(Uri.parse(String.format(mCheckoutUrl, plan)));
                //startActivity(intent);
                return;
            case R.id.cardBtn:
                Log.d(TAG, "Card button pressed");
                return;
            default:
                // Nothing to do
        }
    }

    // loads Stripe checkout inside of a WebView 
    // for Alipay users
    public void loadWebView(String plan) {

        new FinestWebView.Builder(this)
            .webViewSupportMultipleWindows(true)
            .webViewJavaScriptEnabled(true)
            .swipeRefreshColorRes(R.color.black)
            .webViewAllowFileAccessFromFileURLs(true)
            .webViewJavaScriptCanOpenWindowsAutomatically(true)
            //.webViewLoadWithProxy(session.startLocalProxy(this))
            .show(String.format(mCheckoutUrl, plan));

        /*webView.clearCache(true);

        WebSettings mWebSettings = webView.getSettings();
        mWebSettings.setJavaScriptEnabled(true);
        mWebSettings.setJavaScriptCanOpenWindowsAutomatically(true);
        mWebSettings.setSupportMultipleWindows(true);
        webView.setScrollBarStyle(View.SCROLLBARS_OUTSIDE_OVERLAY);
        webView.setWebChromeClient(new MyWebChromeClient(mContext));
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {    
                // load the checkout page in the browser
                view.loadUrl(url);    
                return false;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
            }
        });
        webView.loadUrl(String.format(mCheckoutUrl, chargeAmount));*/
    }

    private class MyWebChromeClient extends WebChromeClient {
        private Context mContext;

        public MyWebChromeClient(Context context) {
            super();
            this.mContext = context;
        }

        @Override
        public boolean onConsoleMessage (ConsoleMessage consoleMessage) {
            Log.d(TAG, "Got a new console message: " 
                    + consoleMessage.message());
            return true;
        }

        @Override
        public boolean onJsAlert(WebView view, String url, String message, final android.webkit.JsResult result)  
        {
            Log.d("alert", message);
            Toast.makeText(mContext, message, 3000).show();
            result.confirm();
            return true;
        }; 
    }

    public void submitCard() {

        final String email = emailInput.getText().toString();
        if (!Utils.isEmailValid(email)) {
            Utils.showErrorDialog(this, "Invalid e-mail address");
            return;
        }

        // TODO: replace with your own test key
        Log.d(TAG, "Submit card button clicked..");
        boolean isDebuggable =  ( 0 != ( getApplicationInfo().flags &= ApplicationInfo.FLAG_DEBUGGABLE ) );
        final String publishableApiKey = isDebuggable ?
            "pk_test_4MSPZvz9QtXGWEKdODmzV9ql" :
            getString(R.string.stripe_publishable_key);
        Card card = new Card(
                paymentForm.getCardNumber(),
                paymentForm.getExpMonth(),
                paymentForm.getExpYear(),
                paymentForm.getCvc());

        boolean validation = card.validateCard();
        if (validation) {
            startProgress();
            Stripe stripe = new Stripe();
            stripe.createToken(card, publishableApiKey, new TokenCallback() {
                public void onSuccess(Token token) {
                    finishProgress(token.getId());
                }

                public void onError(Exception error) {
                    Log.d("Stripe", error.getLocalizedMessage());
                    handleError(error.getLocalizedMessage());
                }
            });
        } else if (!card.validateNumber()) {
            handleError("The card number that you entered is invalid");
        } else if (!card.validateExpiryDate()) {
            handleError("The expiration date that you entered is invalid");
        } else if (!card.validateCVC()) {
            handleError("The CVC code that you entered is invalid");
        } else {
            handleError("The card details that you entered are invalid");
        }
    }

    private void startProgress() {
        progressFragment.show(getSupportFragmentManager(), "progress");
    }

    @Override
    public void onSuccess() {
        Intent intent = new Intent(this, WelcomeActivity_.class);
        this.startActivity(intent);
    }

    @Override
    public void onError() {
        Utils.showErrorDialog(this, 
                getResources().getString(R.string.invalid_payment_method));
    }


    private void finishProgress(String token) {
        progressFragment.dismiss();

        String email = emailInput.getText().toString();

        session.setProUser(email, token, 
                chargeAmount == 799 ? "month" : "year");

        // submit token to Pro server here
        new ProRequest(this).execute("purchase");
    }

    private void handleError(String error) {
        DialogFragment fragment = ErrorDialogFragment.newInstance(R.string.validation_errors, error);
        fragment.show(getSupportFragmentManager(), "error");
    }
}
