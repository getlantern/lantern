package org.lantern.model;

import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

import org.lantern.activity.ProResponse;
import org.lantern.fragment.ProgressDialogFragment;
import android.support.v4.app.FragmentActivity;
import android.support.v4.app.FragmentManager;

import org.lantern.LanternApp;                   
import org.lantern.R;
import org.lantern.model.SessionManager;         

import go.lantern.Lantern;

public class ProRequest extends AsyncTask<String, Void, Boolean> {

    private static final String TAG = "ProRequest";

    private ProgressDialogFragment progressFragment = null;
    private FragmentManager manager;
    private ProResponse response;
    private FragmentActivity activity;
    private String errMsg;
    private SessionManager session;
    private boolean noNetworkConnection = false;

    public ProRequest(ProResponse response, boolean showProgress) {
        this.response = response;
        if (response instanceof FragmentActivity && showProgress) {
            manager = ((FragmentActivity)response).getSupportFragmentManager();
            progressFragment = ProgressDialogFragment.newInstance(R.string.progressMessage);
        }
        session = LanternApp.getSession();
    }

    @Override
    protected void onPreExecute() {
        super.onPreExecute();
        if (progressFragment != null) {
            progressFragment.show(manager, "progress");
        }
    }

    @Override
    protected Boolean doInBackground(String... params) {
        String command = params[0];
        try {

            Context c;
            if (response instanceof LanternApp) {
                c = ((LanternApp)response).getApplicationContext();
            } else {
                c = ((FragmentActivity)response).getApplicationContext();
            }


            if (!Utils.isNetworkAvailable(c)) {
                noNetworkConnection = true;
                return false;
            }

            return Lantern.ProRequest(session.shouldProxy(), command, session);
        } catch (Exception e) {
            Log.e(TAG, "Pro API request error: " + e.getMessage());
        }
        return false;
    }

    @Override
    protected void onPostExecute(Boolean success) {
        super.onPostExecute(success);

        if (progressFragment != null) {
            progressFragment.dismissAllowingStateLoss();
        }

        if (success) {
            response.onSuccess();
        } else {                   
            if (noNetworkConnection && response instanceof FragmentActivity) {
                FragmentActivity activity = (FragmentActivity)response;
                Utils.showErrorDialog(activity, 
                        activity.getResources().getString(R.string.no_internet_connection));

            } else {
                response.onError();
            }
        }
    }
}
