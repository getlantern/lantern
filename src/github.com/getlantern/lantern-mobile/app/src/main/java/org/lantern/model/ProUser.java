package org.lantern.model;

import android.app.Activity;
import android.content.Context;
import android.content.res.Resources;
import android.provider.Settings.Secure;
import android.widget.TextView;

import org.lantern.R;

import go.lantern.Lantern;

/**
 * This just adds some extra params around the pro-server-client User
 *
 */
public class ProUser extends Lantern.ProUser.Stub {
    private long id = 0;
    private String code;
    private String verifyCode;
    private String deviceId;
    private String email;
    private String phoneNumber;
    private String token;
    private String stripeToken;
    private String stripeEmail;
    private String plan;
    private String referral;
    private String[] invitees;
    private Resources res;
    private Context mContext;
    private SessionManager session;

    public ProUser(SessionManager session, Context context) {
        this.session = session;
        this.deviceId = Secure.getString(context.getContentResolver(),
                Secure.ANDROID_ID); 
        final ProUser user = this;
        mContext = context;
        res = context.getResources();
    }

    public void Set(String code, 
            String token, long id) {
        this.id = id;
        this.code = code;
        this.token = token;
    }

    public long UserId() {
        return id;
    }

    public void SetUserData(String[] invitees) {
        this.invitees = invitees;
        String creditsText = String.format(res.getString(R.string.pro_credits_text, invitees.length));
        TextView creditsTextView = (TextView)(((Activity) mContext).findViewById(R.id.pro_credits_text));
        creditsTextView.setText(creditsText);
    }

    public String Code() {
        return code;
    }

    public void ProUserStatus(String status) {
        session.proUserStatus(status);
    }

    public String Referral() {
        return referral;
    }

    public String VerifyCode() {
        return this.verifyCode;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public void setStripeToken(String token) {
        this.stripeToken = token;
    }

    public void setStripeEmail(String email) {
        this.stripeEmail = email;
    }

    public String StripeToken() {
        return this.stripeToken;
    }                           

    public String StripeEmail() {
        return this.stripeEmail;
    }

    public void setReferral(String referral) {
        this.referral = referral;
    }

    public void setVerifyCode(String verifyCode) {
        this.verifyCode = verifyCode;
    }

    public void setId(String id) {
        this.id = Long.valueOf(id).longValue();
    }

    public void setPhoneNumber(String number) {
        this.phoneNumber = number;
    }

    public void setPlan(String plan) {
        this.plan = plan;
    }

    public String PhoneNumber() {
        return phoneNumber;
    }

    public String DeviceId() {
        return deviceId;
    }

    public String Token() {
        return token;
    }

    public String Email() {
        return email;
    }

    public String Plan() {
        return plan;
    }
}  
