package org.lantern.model;

import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.provider.Settings.Secure;
import android.util.Log;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Currency;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.lantern.activity.SignInActivity;
import org.lantern.mobilesdk.StartResult;
import org.lantern.mobilesdk.LanternNotRunningException;
import org.lantern.model.ProPlan;
import org.lantern.vpn.Service;
import org.lantern.R;                                    

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;

import go.lantern.Lantern;

public class SessionManager implements Lantern.Session {

    private static final String TAG = "SessionManager";
    private static final String PREF_NAME = "LanternSession";
    private static final String DEVICE_LINKED = "DeviceLinked";
    private static final String REFERRAL_APPLIED = "ReferralApplied";
    private static final String REFERRAL_CODE = "referral";
    private static final String DEVICE_ID = "deviceid";

    private static final String USER_ID = "userid";
    private static final String PRO_USER = "prouser";
    private static final String PRO_PLAN = "proplan";
    private static final String PHONE_NUMBER = "phonenumber";
    private static final String TOKEN = "token";
    private static final String PREF_USE_VPN = "pref_vpn";
    private static final String PREF_NEWSFEED = "pref_newsfeed";

    private long oneYearCost = 2700;
    private long twoYearCost = 4800;

    private static final String defaultCurrencyCode = "usd";

    private final Map<String, ProPlan> plans = new HashMap<String, ProPlan>();
    private final Map<Locale, List<ProPlan>> localePlans = new HashMap<Locale, List<ProPlan>>();

    // Default Pro Plans
    private final Locale enLocale = new Locale("en", "US");
    private final List<ProPlan> defaultPlans;

     // shared preferences mode
    private int PRIVATE_MODE = 0;

    private Context context;
    private Resources resources;
    private SharedPreferences mPrefs;
    private Editor editor;

    private String phoneNumber;
    private String stripeToken;
    private String stripeEmail;
    private String referral;
    private String verifyCode;
    private String plan;
    private Locale locale;
    private Currency currency;


    public SessionManager(Context context) {
        this.context = context;
        this.mPrefs = context.getSharedPreferences(PREF_NAME, PRIVATE_MODE);
        this.editor = mPrefs.edit();
        this.resources = context.getResources();
        this.locale = resources.getConfiguration().locale;
        this.defaultPlans = new ArrayList<ProPlan>();
        this.defaultPlans.add(createPlan(enLocale, "1y-usd",
                    "One Year Plan", false, 1, 2700));
        this.defaultPlans.add(createPlan(enLocale, "2y-usd",
                    "Two Year Plan", true, 2, 4800));
    }

    public void printDefault() {
        for (ProPlan p : defaultPlans) {
            Log.d(TAG, String.format("Default %s %d plan cost str: %s", 
                    p.getPlanId(), p.getPrice(), p.getCostStr()));
        }
    }

    public boolean isChineseUser() {
        Locale locale = Locale.getDefault();
        return locale.equals(new Locale("zh", "CN")) ||
            locale.equals(new Locale("zh", "TW"));
    }

    public boolean isDeviceLinked() {
        return mPrefs.getBoolean(DEVICE_LINKED, false);
    }

    public boolean isReferralApplied() {
        return mPrefs.getBoolean(REFERRAL_APPLIED, false);
    }

    public boolean isProUser() {
        return mPrefs.getBoolean(PRO_USER, false);
    }

    public String Currency() {
        Currency currency = Currency.getInstance(Locale.getDefault());
        String code = currency.getCurrencyCode();
        Log.d(TAG, "Current currency is " + code);
        if (code != null) {
            return code.toLowerCase();
        }
        return defaultCurrencyCode;
    }

	public void launchActivity(Class c, boolean clearTop) {
		Intent i = new Intent(this.context, c);
		// close all previous activities
		if (clearTop) {
			i.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
		}
		i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

		// start sign in activity
		this.context.startActivity(i);
	}

    public Long getOneYearCost() {
        return oneYearCost;
    }

    public Long getTwoYearCost() {
        return twoYearCost;
    }

    public long getSelectedPlanCost() {
        ProPlan plan = plans.get(this.plan);
        if (plan != null) {
            Long price = plan.getPrice();
            if (price != null) {
                return price.longValue();
            }
        }
        return oneYearCost;
    }

    public static ProPlan createPlan(Locale locale, String id, 
            String description, boolean bestValue, long numYears, 
            long price) {
        ProPlan plan = new ProPlan(id, description, bestValue,
                numYears, price);

        Currency currency = Currency.getInstance(locale);
        String symbol = currency.getSymbol();
        long fmtPrice = price/100;

        String costStr = String.format("%s%d (%s)",
                symbol, fmtPrice, currency.getCurrencyCode());

        plan.setPrice(price);
        plan.setLocale(locale);
        plan.setCostStr(costStr);

        return plan;
    }

    public void savePlan(Resources resources, ProPlan plan) {
        Locale locale = Locale.getDefault();
        Currency currency = Currency.getInstance(locale);
        String symbol = currency.getSymbol();
        long price = plan.getPrice();
        long fmtPrice = price/100;

        String costStr = String.format(resources.getString(R.string.plan_cost),
                symbol, fmtPrice, currency.getCurrencyCode());

        plan.setPrice(price);
        plan.setLocale(locale);
        plan.setCostStr(costStr);
        plans.put(plan.getPlanId(), plan);
        addLocalePlan(plan);

        if (plan.numYears() == 1) {
            setOneYearCost(price);
        } else {
            setTwoYearCost(price);
        }

    }

    public void addLocalePlan(ProPlan plan) {
        List<ProPlan> plans = localePlans.get(plan.getLocale());
        if (plans == null) {
            plans = new ArrayList<ProPlan>();
            localePlans.put(plan.getLocale(), plans);
        }
        plans.add(plan);
    }

    public List<ProPlan> getPlans(Locale locale) {
        List<ProPlan> plans = localePlans.get(locale);
        if (plans == null || plans.isEmpty()) {
            return defaultPlans;
        }
        return plans;
    }

    public void setOneYearCost(long oneYearCost) {
        this.oneYearCost = oneYearCost;
    }

    public void setTwoYearCost(long twoYearCost) {
        this.twoYearCost = twoYearCost;
    }                      

    public void AddPlan(String id, String description, boolean bestValue, long numYears, long price) {
        EventBus.getDefault().post(new ProPlan(id, description, bestValue, numYears, price));
    }

	public boolean deviceLinked() {
		if (!this.isDeviceLinked()) {
			launchActivity(SignInActivity.class, false);
			return false;
		}
		return true;
	}

	public void setPhoneNumber(String number) {
        this.phoneNumber = number;
        editor.putString(PHONE_NUMBER, number).commit();
    }

    public String PhoneNumber() {
        if (phoneNumber == null || phoneNumber.equals("")) {
            return mPrefs.getString(PHONE_NUMBER, "");
        }
        return phoneNumber;
    }

	public void setVerifyCode(String code) {
        this.verifyCode = code;
	}

    @Override
    public String VerifyCode() {
        return this.verifyCode;
    }

    public void UserData(String userStatus, long expiration, String subscription) {
        Log.d(TAG, String.format("Got user data; status=%s expiration=%s subscription=%s", userStatus, expiration, subscription));
    }

	public void proUserStatus(String status) {
		if (status.equals("active")) {
			editor.putBoolean(PRO_USER, true).commit();
		}
	}

    public void setProPlan(String plan) {
        this.plan = plan;
        editor.putString(PRO_PLAN, plan).commit();
    }

    public String getProPlan() {
        return plan;
    }

	public void setProUser(String email, String token) {
        this.stripeToken = token;
        this.stripeEmail = email;
	}

    public void setIsProUser(boolean isProUser) {
        editor.putBoolean(PRO_USER, isProUser).commit();
    }

	public void setStripeToken(String token) {
        this.stripeToken = token;
	}

	public void setStripeEmail(String email) {
        this.stripeEmail = email;
	}

	public void SetCode(String referral) {
		editor.putString(REFERRAL_CODE, referral).commit();
	}      

	public void SetToken(String token) {
		editor.putString(TOKEN, token).commit();
	}

    public String StripeToken() {
        return this.stripeToken;
    }

    public String StripeEmail() {
        return this.stripeEmail;
    }

	public void SetUserId(long userId) {
		editor.putString(USER_ID, Long.toString(userId)).commit();
	}

	private void setDeviceId(String deviceId) {
		editor.putString(DEVICE_ID, deviceId).commit();
	}

    public String DeviceId() {
        String deviceId = mPrefs.getString(DEVICE_ID, null);
        if (deviceId == null) {
            deviceId = Secure.getString(context.getContentResolver(), Secure.ANDROID_ID); 
            setDeviceId(deviceId);
        }
        return deviceId;
    }


    public String Code() {
        return mPrefs.getString(REFERRAL_CODE, "");
    }

	public long UserId() {
        String userId = mPrefs.getString(USER_ID, "");
        if (userId.equals("")) {
            return 0;
        }
		return Long.parseLong(userId);
	}

	public String getUserId() {
		return mPrefs.getString(USER_ID, "");
	}

	public String Token() {
		return mPrefs.getString(TOKEN, "");
	}

	public String getPlan() {
		return mPrefs.getString(PRO_PLAN, "");
	}

	public void setPlanText(TextView proAccountText, Resources res) {
		String currentPlan = this.plan;
		if (currentPlan == null) {
			return;
		}

		if (currentPlan.equals("yearly")) {
			proAccountText.setText(res.getString(R.string.pro_account_year_text));
        } else if (currentPlan.equals("monthly")) {
			proAccountText.setText(res.getString(R.string.pro_account_month_text));
        }
	}

    public boolean useVpn() {
        return mPrefs.getBoolean(PREF_USE_VPN, false);
    }

    public void updateVpnPreference(boolean useVpn) {
        editor.putBoolean(PREF_USE_VPN, useVpn).commit();
    }

    public void updateFeedPreference(boolean pref) {
        editor.putBoolean(PREF_NEWSFEED, pref).commit();
    }   

    public boolean showFeed() {
        return mPrefs.getBoolean(PREF_NEWSFEED, true);
    }

    public void clearVpnPreference() {
        editor.putBoolean(PREF_USE_VPN, false).commit();
    }

	public void setReferral(String referralCode) {
        this.referral = referralCode;
	}

    public String Referral() {
        return referral;
    }

    public String Plan() {
        return plan;
    }

    public String Locale() {
        return Locale.getDefault().toString(); 
    }

	public void setReferralApplied() {
		editor.putBoolean(REFERRAL_APPLIED, true).commit();
	}

	public void unlinkDevice() {
        editor.putBoolean(PRO_USER, false);
        editor.putBoolean(DEVICE_LINKED, false);
        editor.remove(PHONE_NUMBER);
        editor.remove(PRO_PLAN);
		editor.commit();
	}

	public void linkDevice() {
		editor.putBoolean(DEVICE_LINKED, true);
		editor.commit();
	}

    // startLocalProxy starts a separate instance of Lantern
    // used for proxying requests we need to make even before
    // the user enables full-device VPN mode
    public String startLocalProxy() {

        // if the Lantern VPN is already running
        // then we just fetch the feed without
        // starting another local proxy

        if (Service.isRunning(this.context)) {
            return "";
        }

        try {
            int startTimeoutMillis = 60000;
            String analyticsTrackingID = ""; // don't track analytics since those are already being tracked elsewhere
            boolean updateProxySettings = true;

            StartResult result = org.lantern.mobilesdk.Lantern.enable(this.context, 
                startTimeoutMillis, updateProxySettings, analyticsTrackingID);
            return result.getHTTPAddr();
        }  catch (LanternNotRunningException lnre) {
            throw new RuntimeException("Lantern failed to start: " + lnre.getMessage(), lnre);
        }  
    }

	public boolean shouldProxy() {
        return !"".equals(startLocalProxy());
	}

}
