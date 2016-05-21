package org.lantern.model;

import android.os.AsyncTask;
import android.util.Log;

import org.lantern.activity.ProActivity;
import org.lantern.fragment.ProgressDialogFragment;
import android.support.v4.app.FragmentManager;

import org.lantern.LanternApp;                   
import org.lantern.R;
import org.lantern.model.SessionManager;         

import go.lantern.Lantern;

public class ProRequest extends AsyncTask<String, Void, Boolean> {

    private static final String TAG = "ProRequest";


    private ProgressDialogFragment progressFragment;
    private FragmentManager manager;
    private ProActivity activity;
    private String errMsg;
    private SessionManager session;

    public ProRequest(ProActivity activity) {
        this.activity = activity;
        this.manager = activity.getSupportFragmentManager();
        this.session = LanternApp.getSession();
        progressFragment = ProgressDialogFragment.newInstance(R.string.progressMessage);
    }

    @Override
    protected Boolean doInBackground(String... params) {
        String command = params[0];
        progressFragment.show(manager, "progress");
        try {
            String proxyAddr = session.startLocalProxy(activity.getApplicationContext());
            return Lantern.ProRequest(proxyAddr, command, session.getUser());
        } catch (Exception e) {
            Log.e(TAG, "Pro API request error: " + e.getMessage());
        }
        return false;
    }

    @Override
    protected void onPostExecute(Boolean success) {
        super.onPostExecute(success);

        progressFragment.dismiss();
        if (success) {
            activity.onSuccess();
        } else {
            activity.onError();
        }
    }
}
