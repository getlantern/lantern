package org.lantern.activity;

import android.app.Activity;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.net.Uri;
import android.net.UrlQuerySanitizer;
import android.support.design.widget.CoordinatorLayout;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentActivity;

import com.stripe.android.Stripe;
import com.stripe.android.TokenCallback;
import com.stripe.android.model.Card;
import com.stripe.android.model.Token;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.Click;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.FragmentById;
import org.androidannotations.annotations.ViewById;

import org.lantern.LanternApp;
import org.lantern.fragment.ErrorDialogFragment;
import org.lantern.fragment.PaymentFormFragment;
import org.lantern.model.ProRequest;
import org.lantern.model.ProResponse;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

import com.thefinestartist.finestwebview.FinestWebView;
import com.thefinestartist.finestwebview.FinestWebViewActivity.MyWebViewClient;
import info.hoang8f.android.segmented.SegmentedGroup;

@EActivity(R.layout.checkout)
public class PaymentActivity extends FragmentActivity implements ProResponse, View.OnClickListener {

    private static final String TAG = "PaymentActivity";
    public static final String CHECKOUT_URL = "file:///android_asset/checkout.html?key=%s&price=%d&currency=%s";

    private SessionManager session;

    private long chargeAmount;

    private ProgressDialog dialog;

	private boolean isDebuggable;
	private String apiKey;

    @FragmentById(R.id.payment_form)
    PaymentFormFragment paymentForm;

    @ViewById
    TextView chargeAmountView;

    @ViewById
    CoordinatorLayout coordinatorLayout;

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
	    isDebuggable =  ( 0 != ( getApplicationInfo().flags &= ApplicationInfo.FLAG_DEBUGGABLE ) );
		apiKey = isDebuggable ?
			"pk_test_4MSPZvz9QtXGWEKdODmzV9ql" :
			"pk_live_4MSPfR6qNHMwjG86TZJv4NI0";

        session = LanternApp.getSession();

        segmented.setTintColor(getResources().getColor(R.color.pro_blue_color));

        cardBtn.setOnClickListener(this);
        alipayBtn.setOnClickListener(this);

        Intent intent = getIntent();
        if (intent != null && intent.getExtras() != null &&
                intent.getExtras().getBoolean("referralApplied")) {
            // if the user successfully applied a promotion, show a snackbar
            // notification regarding this when they arrive on the checkout screen
            Utils.showPlainSnackbar(coordinatorLayout,
                    getResources().getString(R.string.referral_applied));
        }

        chargeAmount = session.getSelectedPlanCost();
        Log.d(TAG, "Charge amount is " + chargeAmount);
        chargeAmountView.setText(Utils.formatMoney(session, chargeAmount));

        final Context context = PaymentActivity.this;

        dialog = new ProgressDialog(context);
        dialog.setCancelable(true);

        dialog.setMessage(context.getResources().getString(R.string.sending_request));

        Uri data = intent.getData();

        if (data != null && data.getQueryParameter("stripeToken") != null) {
            dialog.show();

            String stripeToken = data.getQueryParameter("stripeToken");
            String stripeEmail = data.getQueryParameter("stripeEmail");  
            Log.d(TAG, "From browser, token " + stripeToken + " " + stripeEmail);
            finishProgress(stripeEmail, stripeToken);
        }
    }

    @Click(R.id.checkoutBtn)
    void checkout() {
      submitCard();
    }

    @Override
    public void onClick(View v) {
        Log.d(TAG, "onclick called...");
        switch (v.getId()) {
            case R.id.alipayBtn:
                Log.d(TAG, "Alipay button pressed");
                openAlipayWebview(PaymentActivity.this, session);
                return;
            case R.id.cardBtn:
                Log.d(TAG, "Card button pressed");
                return;
            default:
                // Nothing to do
        }
    }

    public static void openAlipayWebview(Context c, SessionManager session) {
        Log.d(TAG, "Opening Alipay in a webview!!");
		long amount = session.getSelectedPlanCost();
		boolean isDebuggable =  ( 0 != ( c.getApplicationInfo().flags &= ApplicationInfo.FLAG_DEBUGGABLE ) );
		String key = isDebuggable ?
			"pk_test_4MSPZvz9QtXGWEKdODmzV9ql" :
			"pk_live_4MSPfR6qNHMwjG86TZJv4NI0";

        String currency = session.getSelectedPlanCurrency();

		String url = String.format(CHECKOUT_URL, key, amount, currency);

        new FinestWebView.Builder((Activity)c)
            .webViewSupportMultipleWindows(true)
            .webViewJavaScriptEnabled(true)
			.webViewInsideScrollStyle(true)
            .swipeRefreshColorRes(R.color.black)
            .webViewAllowFileAccessFromFileURLs(true)
            .webViewJavaScriptCanOpenWindowsAutomatically(true)
            .webViewLoadWithProxy(session.startLocalProxy())
            .show(url);
    }

    public void submitCard() {

        final String email = emailInput.getText().toString();
        if (!Utils.isEmailValid(email)) {
            Utils.showErrorDialog(this, "Invalid e-mail address");
            return;
        }

        Log.d(TAG, "Submit card button clicked..");
        Card card = new Card(
                paymentForm.getCardNumber(),
                paymentForm.getExpMonth(),
                paymentForm.getExpYear(),
                paymentForm.getCvc());

        boolean validation = card.validateCard();
        if (validation) {
            dialog.show();
            Stripe stripe = new Stripe();
            stripe.createToken(card, apiKey, new TokenCallback() {
                public void onSuccess(Token token) {
                    finishProgress(emailInput.getText().toString(), token.getId());
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

    @Override
    public void onResult(boolean success) {
        if (dialog != null && dialog.isShowing()) {
            dialog.dismiss();
        }         

        if (!success) {
            Utils.showErrorDialog(this, 
                    getResources().getString(R.string.invalid_payment_method));
            return;
        }

        session.linkDevice();
        session.setIsProUser(true);
        startActivity(new Intent(this, WelcomeActivity_.class));
    }

	@Override
	public void onDestroy() {
    	super.onDestroy();
		if (dialog != null) {
        	dialog.dismiss();
			dialog = null;
		}
	}

    private void finishProgress(String email, String token) {

        String currency = session.getSelectedPlanCurrency();

        Log.d(TAG, String.format("Email is %s token %s plan %s user id %s token %s plan %s currency %s device id %s", 
                    email, token, session.Plan(), session.UserId(), session.Token(), session.getPlan(), currency, session.DeviceId()));

        session.setProUser(email, token);

        // submit token to Pro server here
        new ProRequest(PaymentActivity.this, false, this).execute("purchase");
    }

    private void handleError(String error) {
		if (dialog != null && dialog.isShowing()) {
			dialog.dismiss();
		}         

        DialogFragment fragment = ErrorDialogFragment.newInstance(R.string.validation_errors, error);
        fragment.show(getSupportFragmentManager(), "error");
    }
}
