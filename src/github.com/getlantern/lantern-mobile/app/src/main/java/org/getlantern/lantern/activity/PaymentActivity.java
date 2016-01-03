package org.getlantern.lantern.activity;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import android.support.v4.app.Fragment;
import android.support.v4.app.DialogFragment;
import android.support.v4.app.FragmentActivity;

import com.stripe.android.Stripe;
import com.stripe.android.TokenCallback;
import com.stripe.android.model.Card;
import com.stripe.android.model.Token;

import org.getlantern.lantern.fragment.PaymentFormFragment;
import org.getlantern.lantern.model.ErrorDialogFragment;
import org.getlantern.lantern.model.ProgressDialogFragment;
import org.getlantern.lantern.model.PaymentForm;
import org.getlantern.lantern.R;

public class PaymentActivity extends FragmentActivity {

    private static final String TAG = "PaymentActivity";
    private static final String publishableApiKey = "pk_test_4MSPZvz9QtXGWEKdODmzV9ql";

    private ProgressDialogFragment progressFragment;
    private Button checkoutBtn;
    private PaymentFormFragment paymentForm;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.checkout);

        paymentForm = (PaymentFormFragment)getSupportFragmentManager().findFragmentById(R.id.payment_form);

        checkoutBtn = (Button)findViewById(R.id.checkoutBtn);
        checkoutBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                submitCard();
            }
        });

        progressFragment = ProgressDialogFragment.newInstance(R.string.progressMessage);
		ImageView backBtn = (ImageView)findViewById(R.id.paymentAvatar);
		backBtn.setOnClickListener(new View.OnClickListener() {

			@Override
			public void onClick(View v) {
				Log.d(TAG, "Back button pressed");
				finish();
			}
		});
    }

	public void submitCard() {
		// TODO: replace with your own test key
		Log.d(TAG, "Submit card button clicked..");
		//final String publishableApiKey = BuildConfig.DEBUG ?
		//"pk_test_4MSPZvz9QtXGWEKdODmzV9ql" :
		//getString(R.string.com_stripe_publishable_key);
        //
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
                    // TODO: Send Token information to your backend to initiate a charge
                    Toast.makeText(
                            getApplicationContext(),
                            "Token created: " + token.getId(),
                            Toast.LENGTH_LONG).show();
                    finishProgress();
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

    private void finishProgress() {
        progressFragment.dismiss();

        // submit token to Pro server here

        Intent intent = new Intent(this, WelcomeActivity.class);
        this.startActivity(intent);
    }

    private void handleError(String error) {
        DialogFragment fragment = ErrorDialogFragment.newInstance(R.string.validation_errors, error);
        fragment.show(getSupportFragmentManager(), "error");
    }
}
