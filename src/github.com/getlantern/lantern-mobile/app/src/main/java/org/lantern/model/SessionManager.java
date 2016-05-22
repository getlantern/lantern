package org.lantern.model;

import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.os.AsyncTask;
import android.util.Log;
import android.widget.TextView;

import org.lantern.activity.SignInActivity;
import org.lantern.activity.ProResponse;
import org.lantern.mobilesdk.StartResult;
import org.lantern.mobilesdk.LanternNotRunningException;
import org.lantern.model.ProUser;
import org.lantern.vpn.Service;
import org.lantern.R;                                    

public class SessionManager implements ProResponse {

    private static final String TAG = "SessionManager";
    private static final String PREF_NAME = "LanternSession";
    private static final String DEVICE_LINKED = "DeviceLinked";
    private static final String REFERRAL_APPLIED = "ReferralApplied";
    private static final String REFERRAL_CODE = "referral";
    private static final String DEVICE_ID = "deviceid";

    public static int chargeAmount = 0;
    public static String chargeStr = "";
    private ProUser mProUser;

    private static final String USER_ID = "userid";
    private static final String PRO_USER = "prouser";
    private static final String PRO_PLAN = "proplan";
    private static final String TOKEN = "token";
    private static final String PREF_USE_VPN = "pref_vpn";
    private static final String PREF_NEWSFEED = "pref_newsfeed";

     // shared preferences mode
    private int PRIVATE_MODE = 0;

    private Context context;
    private SharedPreferences mPrefs;
    private Editor editor;

    public SessionManager(Context context) {
        this.context = context;
        this.mPrefs = context.getSharedPreferences(PREF_NAME, PRIVATE_MODE);
        this.mProUser = new ProUser(context);
        this.editor = mPrefs.edit();

		new NewSession(context).execute();
    }

	@Override
	public void onSuccess() {

	}

	@Override
	public void onError() {

	}

    private class NewSession extends AsyncTask<Void, Void, ProUser> {

        private boolean showFeed = false;
        private Context context;

        public NewSession(Context context) {
            this.context = context;
        }

        @Override
        protected void onPreExecute() {
            super.onPreExecute();
            this.showFeed = showFeed();
        }

        @Override
        protected ProUser doInBackground(Void... params) {
            try {
				ProUser user = new ProUser(context);
				boolean shouldProxy = shouldProxy();
				boolean status = go.lantern.Lantern.ProRequest(shouldProxy, "newuser", user);
				if (status) {
                	return user;
				}
            } catch (Exception e) {
                Log.e(TAG, "Pro API request error: " + e.getMessage());
            }

            return null;
        }

        @Override
        protected void onPostExecute(final ProUser user) {
            super.onPostExecute(user);
            if (user != null) {
                Log.d(TAG, "Successfully created new Pro user: " + user.UserId());
                setCode(user.Code());
                setToken(user.Token());
                setUserId(Long.toString(user.UserId()));
                setDeviceId(user.DeviceId());
            } else {
                Log.e(TAG, "Could not create new Pro user");
            }
        }
    }

	public void checkProStatus() {
		
    	
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

	public boolean deviceLinked() {
		if (!this.isDeviceLinked()) {
			launchActivity(SignInActivity.class, false);
			return false;
		}
		return true;
	}

	public void setPhoneNumber(String number) {
		mProUser.setPhoneNumber(number);
	}

	public void setVerifyCode(String code) {
		mProUser.setVerifyCode(code);
	}                 

	public void proUserStatus(String status) {
		if (status.equals("active")) {
			editor.putBoolean(PRO_USER, true).commit();
		}
	}

	public void setProUser(String email, String token, 
			String plan) {

		setStripeEmail(email);
		setStripeToken(token);
		setPlan(plan);

		editor.putBoolean(PRO_USER, true);
		editor.putString(PRO_PLAN, plan).commit();
	}

	public void setStripeToken(String token) {
		mProUser.setStripeToken(token);
	}

	public void setStripeEmail(String email) {
		mProUser.setStripeEmail(email);
	}

	private void setCode(String referral) {
		editor.putString(REFERRAL_CODE, referral).commit();
	}      

	private void setToken(String token) {
		editor.putString(TOKEN, token).commit();
	}

	private void setUserId(String userId) {
		editor.putString(USER_ID, userId).commit();
	}

	private void setDeviceId(String deviceId) {
		editor.putString(DEVICE_ID, deviceId).commit();
	}


    public String getCode() {
        return mPrefs.getString(REFERRAL_CODE, "");
    }

	public int UserId() {
		String userIdStr = getUserId();
		if (userIdStr.equals("")) {
			return 0;
		}
		return Integer.parseInt(userIdStr);
	}

	public String getUserId() {
		return mPrefs.getString(USER_ID, "");
	}

	public String getToken() {
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

	public void setPlan(String plan) {
		mProUser.setPlan(plan);
	}

    public ProUser getProUser() {
        return mProUser;
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
		mProUser.setReferral(referralCode);
	}

	public void setReferralApplied() {
		editor.putBoolean(REFERRAL_APPLIED, true).commit();
	}

	public void unlinkDevice() {
		editor.clear();
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
