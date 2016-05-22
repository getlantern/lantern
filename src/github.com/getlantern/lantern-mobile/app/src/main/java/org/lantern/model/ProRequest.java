package org.lantern.model;

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
    private String errMsg;
    private SessionManager session;

    public ProRequest(ProResponse response) {
        this.response = response;
        if (response instanceof FragmentActivity) {
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
            progressFragment.dismiss();
        }

        if (success) {
            response.onSuccess();
        } else {
            response.onError();
        }
    }
}
