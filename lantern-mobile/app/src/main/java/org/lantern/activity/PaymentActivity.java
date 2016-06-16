package org.lantern.activity;

import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.net.Uri;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.webkit.WebView;
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
import org.lantern.fragment.ProgressDialogFragment;
import org.lantern.model.ProRequest;
import org.lantern.model.ProResponse;
import org.lantern.model.SessionManager;
import org.lantern.model.Utils;
import org.lantern.R;

import com.thefinestartist.finestwebview.FinestWebView;
import info.hoang8f.android.segmented.SegmentedGroup;

@EActivity(R.layout.checkout)
public class PaymentActivity extends FragmentActivity implements ProResponse, View.OnClickListener {

    private static final String TAG = "PaymentActivity";
    private static final String mCheckoutUrl = "https://stripe.com/docs/checkout?plan=%s";

    private SessionManager session;
    private Context mContext;

    private ProgressDialogFragment progressFragment;

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

        segmented.setTintColor(getResources().getColor(R.color.pro_blue_color));

        cardBtn.setOnClickListener(this);
        alipayBtn.setOnClickListener(this);

        Intent intent = getIntent();

        long chargeAmount = session.getSelectedPlanCost();
        Log.d(TAG, "Charge amount is " + chargeAmount);
        chargeAmountView.setText(Utils.formatMoney(chargeAmount));

        progressFragment = ProgressDialogFragment.newInstance(R.string.progressMessage);

        Uri data = intent.getData();

        if (data != null && data.getQueryParameter("stripeToken") != null) {
            String stripeToken = data.getQueryParameter("stripeToken");
            String stripeEmail = data.getQueryParameter("stripeEmail");  
            startProgress();
            finishProgress(stripeEmail, stripeToken.substring(1));
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
                String url = String.format(mCheckoutUrl, "");
                new FinestWebView.Builder(this)
                    .webViewUseWideViewPort(true)
                    .webViewUserAgentString("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.4) Gecko/20100101 Firefox/4.0")
                    .webViewSupportMultipleWindows(true)
                    .webViewJavaScriptEnabled(true)
                    .swipeRefreshColorRes(R.color.black)
                    .webViewAllowFileAccessFromFileURLs(true)
                    .webViewJavaScriptCanOpenWindowsAutomatically(true)
                    // if we aren't in full-device VPN mode, configure the 
                    // WebView to use our local proxy
                    .show(url);

                /*Intent intent = new Intent(Intent.ACTION_VIEW);
                intent.setData(Uri.parse(url));
                startActivity(intent);*/
                return;
            case R.id.cardBtn:
                Log.d(TAG, "Card button pressed");
                return;
            default:
                // Nothing to do
        }
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

    private void startProgress() {
        progressFragment.show(getSupportFragmentManager(), "progress");
    }

    @Override
    public void onResult(boolean success) {
        if (!success) {
            Utils.showErrorDialog(this, 
                    getResources().getString(R.string.invalid_payment_method));
            return;
        }
        session.setIsProUser(true);
        startActivity(new Intent(this, WelcomeActivity_.class));
    }

    private void finishProgress(String email, String token) {

        Log.d(TAG, String.format("Email is %s token %s plan %s", 
                    email, token, session.getProPlan()));

        session.setProUser(email, token);

        // submit token to Pro server here
        new ProRequest(getApplicationContext(), false, this).execute("purchase");

        if (progressFragment != null) {
            progressFragment.dismiss();
        }
    }

    private void handleError(String error) {
        DialogFragment fragment = ErrorDialogFragment.newInstance(R.string.validation_errors, error);
        fragment.show(getSupportFragmentManager(), "error");
    }
}
