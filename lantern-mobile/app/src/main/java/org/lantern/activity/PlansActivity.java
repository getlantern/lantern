package org.lantern.activity;

import android.content.Intent;
import android.net.Uri;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.ViewById;
import org.androidannotations.annotations.res.StringArrayRes;

import java.util.Currency;
import java.util.Locale;

import org.lantern.LanternApp;
import org.lantern.activity.PaymentActivity;
import org.lantern.model.FeatureUi;
import org.lantern.model.ProPlanEvent;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.R;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;

import go.lantern.Lantern;

@EActivity(R.layout.pro_plans)
public class PlansActivity extends FragmentActivity {

    private static final String TAG = "PlansActivity";
    private static final String mCheckoutUrl = 
        "https://s3.amazonaws.com/lantern-android/checkout.html?amount=%s";
    private boolean useAlipay = false;

    private SessionManager session;

    @StringArrayRes(R.array.pro_features)
    String[] proFeaturesList;

    @ViewById
    Button oneYearBtn, twoYearBtn;

    @ViewById
    TextView oneYearCost, twoYearCost;

    @ViewById
    LinearLayout leftFeatures, rightFeatures;

    @ViewById(R.id.plans_view)
    LinearLayout plansView;

    @AfterViews
    void afterViews() {

        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);         
        }

        session = LanternApp.getSession();
        useAlipay = session.isChineseUser();

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

        plansView.bringToFront();

        Lantern.ProRequest(session.shouldProxy(), "plans", session);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        EventBus.getDefault().unregister(this);
    }

    @Subscribe
    public void onEvent(ProPlanEvent plan) {
        Log.d(TAG, "Received a new pro plan: " + plan.getPlanId());
        Currency currency = Currency.getInstance(Locale.getDefault());
        String symbol = currency.getSymbol();
        long price = plan.getPrice()/100;
        String costStr = String.format(getResources().getString(R.string.plan_cost),
                symbol, price, currency.getCurrencyCode());
        if (plan.numYears() == 1) {
            oneYearCost.setText(costStr);
            oneYearBtn.setTag(plan.getPlanId());
            session.setOneYearCost(price);
        } else {
            twoYearCost.setText(costStr);
            twoYearBtn.setTag(plan.getPlanId());
            session.setTwoYearCost(price);
        }
        session.setPlanPrice(plan.getPlanId(), price);
    }

    public void selectPlan(View view) {
        String plan = "s1y-cny";
        if (view.getTag() != null) {
            plan = (String)view.getTag();
        }

		Log.d(TAG, "Plan selected: " + plan);

        session.setProPlan(plan);

        Intent intent;

        if (useAlipay) {
            Log.d(TAG, "Chinese user detected; opening Alipay by default");
            intent = new Intent(Intent.ACTION_VIEW);
            intent.setData(Uri.parse(String.format(mCheckoutUrl, plan)));

        } else {
            intent = new Intent(this, PaymentActivity.class);
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
