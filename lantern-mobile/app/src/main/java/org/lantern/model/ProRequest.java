package org.lantern.model;

import android.app.Activity;
import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

import org.lantern.fragment.ProgressDialogFragment;
import android.support.v4.app.FragmentActivity;
import android.support.v4.app.FragmentManager;

import org.lantern.LanternApp;                   
import org.lantern.R;
import org.lantern.model.SessionManager;         

import go.lantern.Lantern;

public class ProRequest extends AsyncTask<String, Void, Boolean> {

    private static final String TAG = "ProRequest";

	private ProResponse callback;

    private Context context;
    private String command;
    private ProgressDialogFragment progressFragment = null;
    private FragmentManager manager;
    private String errMsg;
    private SessionManager session;
    private boolean noNetworkConnection = false;

    public ProRequest(Context context, boolean showProgress, ProResponse callback) {
        this.context = context;
	    this.callback = callback;
        this.session = LanternApp.getSession();

        if (showProgress) {
            progressFragment = ProgressDialogFragment.newInstance(R.string.progressMessage);
        }
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
        this.command = params[0];
        try {

            if (!Utils.isNetworkAvailable(context)) {
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

		if (callback != null) {
			callback.onResult(success);
		}
    }
}
