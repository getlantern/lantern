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
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.lantern.LanternApp;
import org.lantern.activity.PaymentActivity;
import org.lantern.model.FeatureUi;
import org.lantern.model.ProPlan;
import org.lantern.model.ProRequest;
import org.lantern.model.SessionManager;
import org.lantern.R;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import go.lantern.Lantern;

@EActivity(R.layout.pro_plans)
public class PlansActivity extends FragmentActivity {

    private static final String TAG = "PlansActivity";
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

        updatePrices(Locale.getDefault());

        new ProRequest(this, false, null).execute("plans");
    }

    // updatePrices updates the stored plan prices 
    // for the given locale
    private void updatePrices(Locale locale) {
        List<ProPlan> plans = session.getPlans(locale);

        for (ProPlan plan : plans) {
            updatePrice(plan);
        }
    }

    private void updatePrice(ProPlan plan) {
        if (plan.numYears() == 1) {
            oneYearCost.setText(plan.getCostStr());
            oneYearBtn.setTag(plan.getPlanId());
        } else {
            twoYearCost.setText(plan.getCostStr());
            twoYearBtn.setTag(plan.getPlanId());
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        EventBus.getDefault().unregister(this);
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onEventMainThread(ProPlan plan) {
        Log.d(TAG, "Received a new pro plan: " + plan.getPlanId());
        session.savePlan(getResources(), plan);
        updatePrice(plan);
    }

    public void selectPlan(View view) {
        String plan = "2y-usd";
        if (view.getTag() != null) {
            plan = (String)view.getTag();
        }

        Log.d(TAG, "Plan selected: " + plan);

        session.setProPlan(plan);

        if (!session.isReferralApplied()) {
            Intent i = new Intent(this,
                    ReferralCodeActivity_.class);
            // close all previous activities
            i.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
            i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(i);
        } else {
            if (!session.isChineseUser()) {
                startActivity(new Intent(this, PaymentActivity.class));
                return;
            } 
            PaymentActivity.openAlipay(PlansActivity.this, session);
        }
    }
}  
