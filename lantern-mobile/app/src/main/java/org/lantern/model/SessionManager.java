package org.lantern.model;

import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.provider.Settings.Secure;
import android.util.Log;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Currency;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.lantern.activity.SignInActivity;
import org.lantern.mobilesdk.StartResult;
import org.lantern.mobilesdk.LanternNotRunningException;
import org.lantern.model.Device;
import org.lantern.model.ProPlan;
import org.lantern.model.ProRequest;
import org.lantern.vpn.Service;
import org.lantern.R;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;

import go.lantern.Lantern;

public class SessionManager implements Lantern.Session, Lantern.UserConfig {

    private static final String TAG = "SessionManager";

    // shared preferences
    private static final String PREF_NAME = "LanternSession";
    private static final String DEVICE_LINKED = "DeviceLinked";
    private static final String REFERRAL_APPLIED = "ReferralApplied";
    private static final String REFERRAL_CODE = "referral";
    private static final String DEVICE_ID = "deviceid";

    private static final String USER_ID = "userid";
    private static final String PRO_USER = "prouser";
    private static final String PRO_PLAN = "proplan";
    private static final String EMAIL_ADDRESS = "emailAddress";
    private static final String EXPIRY_DATE = "expirydate";
    private static final String TOKEN = "token";
    private static final String PREF_USE_VPN = "pref_vpn";
    private static final String PREF_NEWSFEED = "pref_newsfeed";
    private static final String defaultCurrencyCode = "usd";

    // the devices associated with a user's Pro account
    private Map<String, Device> devices = new HashMap<String, Device>();
    private final Map<String, ProPlan> plans = new HashMap<String, ProPlan>();

    private final Map<Locale, List<ProPlan>> localePlans = new HashMap<Locale, List<ProPlan>>();

	private long oneYearCost = 2700;
	private long twoYearCost = 4800;

	// Default Pro Plans
	private static final Locale enLocale = new Locale("en", "US");
	private static final ProPlan defaultOneYearPlan = 
		createPlan(enLocale, "1y-usd", "usd", "One Year Plan", false, 1, 2700);
	private static final ProPlan defaultTwoYearPlan = 
		createPlan(enLocale, "2y-usd", "usd", "Two Year Plan", true, 2, 4800); 
	private static final List<ProPlan> defaultPlans = new ArrayList<ProPlan>() {
		{
			add(defaultOneYearPlan);
			add(defaultTwoYearPlan);
		}
	};

     // shared preferences mode
    private static final int PRIVATE_MODE = 0;

    private Context context;
    private Resources resources;
    private SharedPreferences mPrefs;
    private Editor editor;

    private String stripeToken;
    private String referral;
    private String verifyCode;
    private Locale locale;


    public SessionManager(Context context) {
        this.context = context;
        this.mPrefs = context.getSharedPreferences(PREF_NAME, PRIVATE_MODE);
        this.editor = mPrefs.edit();
        this.resources = context.getResources();
		if (resources.getConfiguration() != null) {
        	this.locale = resources.getConfiguration().locale;
		}
		plans.put(defaultOneYearPlan.getPlanId(), defaultOneYearPlan);
		plans.put(defaultTwoYearPlan.getPlanId(), defaultTwoYearPlan); 
    }

    public void newUser() {
        String proToken = Token();
        if (proToken == null || proToken.equals("")) {
            new ProRequest(context, false, null).execute("newuser");
        } else {
            Log.d(TAG, "Pro token is " + proToken);
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

    public int getNumFreeMonths() {
        return 0;
    }

    public boolean isProUser() {
        return mPrefs.getBoolean(PRO_USER, false);
    }

    public String Currency() {
        ProPlan plan = getSelectedPlan();
        if (plan != null) {
            return plan.getCurrency();
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

    public ProPlan getSelectedPlan() {
        String currentPlan = getPlan();
        if (currentPlan == null) {
            Log.e(TAG, "Error trying to retrieve plan");
            return null;
        }
        Log.d(TAG, "Current plan is " + currentPlan);
        return plans.get(currentPlan);
    }

    public long getSelectedPlanCost() {
        ProPlan plan = getSelectedPlan();
        if (plan != null) {
            Long price = plan.getPrice();
            if (price != null) {
                return price.longValue();
            }
        } else {
            Log.e(TAG, "Selected plan is null");
        }
        return oneYearCost;
    }

    public String[] getReferralArray(Resources res) {
        ProPlan plan = getSelectedPlan();
        if (plan == null) {
			Log.d(TAG, "Selected plan is null. Returning default referral instructions");
			return res.getStringArray(R.array.referral_promotion_list);
        }
        if (plan.numYears() == 1) {
            return res.getStringArray(R.array.referral_promotion_list);
        } else {
            return res.getStringArray(R.array.referral_promotion_list_two_year);
        }
    }

    public String getSelectedPlanCurrency() {
        ProPlan plan = getSelectedPlan();
        if (plan != null) {
            return plan.getCurrency();
        }
        return "usd";
    }

    public void AddDevice(String id, String name) {
        Device device = new Device(id, name);
        devices.put(id, device);
        EventBus.getDefault().post(device);
    }

    public void removeDevice(String id) {
        devices.remove(id);
    }

    public Map<String, Device> getDevices() {
        return devices;
    }

    public static ProPlan createPlan(Locale locale, String id,
            String currency,
            String description, boolean bestValue, long numYears,
            long price) {
        
        ProPlan plan = new ProPlan(id, description, currency, 
                bestValue, numYears, price);

        plan.setLocale(locale);

        return plan;
    }

    public void savePlan(Resources resources, ProPlan plan) {
        Locale locale = Locale.getDefault();

        Log.d(TAG, "Got a new plan! ID is " + plan.getPlanId());

        plan.setLocale(locale);
        plans.put(plan.getPlanId(), plan);
        addLocalePlan(plan);

        if (plan.numYears() == 1) {
            setOneYearCost(plan.getPrice());
        } else {
            setTwoYearCost(plan.getPrice());
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
        List<ProPlan> nPlans = localePlans.get(locale);
        if (nPlans == null || nPlans.isEmpty()) {
            return defaultPlans;
        }
        return nPlans;
    }

    public void setOneYearCost(long oneYearCost) {
        this.oneYearCost = oneYearCost;
    }

    public void setTwoYearCost(long twoYearCost) {
        this.twoYearCost = twoYearCost;
    }

    public void AddPlan(String id, String description, String currency, 
            boolean bestValue, long numYears, long price) {
        EventBus.getDefault().post(new ProPlan(id, description, currency, 
                    bestValue, numYears, price));
    }

	public boolean deviceLinked() {
		if (!this.isDeviceLinked()) {
			launchActivity(SignInActivity.class, false);
			return false;
		}
		return true;
	}

	public void setVerifyCode(String code) {
        Log.d(TAG, "Verify code set to " + code);
        this.verifyCode = code;
	}

    public String VerifyCode() {
        return this.verifyCode;
    }

    public void UserData(String userStatus, long expiration, String subscription) {
        Log.d(TAG, String.format("Got user data; status=%s expiration=%s subscription=%s", userStatus, expiration, subscription));
        setExpiration(expiration);
    }

    private void setExpiration(long expiration) {
        Date expiry = new Date(expiration * 1000);
        SimpleDateFormat dateFormat = new SimpleDateFormat("MM/dd/yyyy");
        String dateToStr = dateFormat.format(expiry);
        Log.d(TAG, "Lantern pro expiration date: " + dateToStr);
        editor.putString(EXPIRY_DATE, dateToStr).commit();
    }

    public String getExpiration() {
        return mPrefs.getString(EXPIRY_DATE, "");
    }

	public void proUserStatus(String status) {
		if (status.equals("active")) {
			editor.putBoolean(PRO_USER, true).commit();
		}
	}

    public void setProPlan(String plan) {
        editor.putString(PRO_PLAN, plan).commit();
    }

	public void setProUser(String email, String token) {
        this.stripeToken = token;
        editor.putString(EMAIL_ADDRESS, email).commit();
	}

    public void setIsProUser(boolean isProUser) {
        editor.putBoolean(PRO_USER, isProUser).commit();
    }

	public void setStripeToken(String token) {
        this.stripeToken = token;
	}

	public void setEmail(String email) {
        editor.putString(EMAIL_ADDRESS, email).commit();
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

    public String Email() {
        return mPrefs.getString(EMAIL_ADDRESS, "");
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

	public String DeviceName() {
		return android.os.Build.MODEL;
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

	public String Token() {
		return mPrefs.getString(TOKEN, "");
	}

	public String getPlan() {
		return mPrefs.getString(PRO_PLAN, "");
	}

	public void setPlanText(TextView proAccountText, Resources res) {
		String currentPlan = getPlan();
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
        return getPlan();
    }

    public String Locale() {
        return Locale.getDefault().toString();
    }

	public void setReferralApplied() {
		editor.putBoolean(REFERRAL_APPLIED, true).commit();
	}

	public void unlinkDevice() {
        devices.clear();

        editor.putBoolean(PRO_USER, false);
        editor.putBoolean(REFERRAL_APPLIED, false);
        editor.putBoolean(DEVICE_LINKED, false);
        editor.remove(TOKEN);
        editor.remove(EMAIL_ADDRESS);
        editor.remove(USER_ID);
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
                startTimeoutMillis, updateProxySettings, analyticsTrackingID, this);

            return result.getHTTPAddr();
        }  catch (LanternNotRunningException lnre) {
            throw new RuntimeException("Lantern failed to start: " + lnre.getMessage(), lnre);
        }
    }

    public void BandwidthUpdate(long quota, long remaining) {
        EventBus.getDefault().post(new Bandwidth(quota, remaining));
    }

    public void AfterStart() {
        newUser();
        new GetFeed(this.context).execute(shouldProxy());
        new ProRequest(this.context, false, null).execute("plans");
    }


	public boolean shouldProxy() {
        return !"".equals(startLocalProxy());
	}

}
