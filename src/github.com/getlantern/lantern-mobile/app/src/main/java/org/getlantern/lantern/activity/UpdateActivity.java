package org.getlantern.lantern.activity;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.Uri;
import android.os.AsyncTask;
import android.util.Log;
import android.view.View.OnClickListener;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.Click;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.Extra;

import go.lantern.Lantern;
import org.getlantern.lantern.LanternApp;
import org.getlantern.lantern.model.SessionManager;
import org.getlantern.lantern.R;

import java.io.File;

@EActivity(R.layout.activity_updater)
public class UpdateActivity extends Activity {

    private static final String TAG = "UpdateActivity";
    private static final String APK_PATH = "/sdcard/Lantern.apk";

    private UpdaterTask mUpdaterTask;
    private ProgressDialog progressBar;
    private SessionManager session;
    private boolean fileDownloading = false;

    static boolean active = false;

    @Extra("updateUrl")
    String updateUrl;

    @Override
    protected void onStart() {
        super.onStart();
        active = true;
    }                  

    @Override
    protected void onStop() {
        super.onStop();
        active = false;
    }
    

    @AfterViews
    void afterViews() {
        session = LanternApp.getSession();
    }

    @Click(R.id.notNow)
    void notNowClicked() {
        finish();
    }

    @Click(R.id.installUpdate)
    void installUpdateClicked() {

        fileDownloading = true;

        String[] updaterParams = {updateUrl};
        mUpdaterTask = new UpdaterTask(this);
        mUpdaterTask.execute(updaterParams);
    }

    private class UpdaterTask extends AsyncTask<String, Long, Boolean> implements DialogInterface.OnClickListener {

        private final UpdateActivity mActivity;
        private final Context context;

        UpdaterTask(final UpdateActivity activity) {
            mActivity = activity;
            context = mActivity.getApplicationContext();
        }

        @Override
        public void onClick(DialogInterface dialog, int which) {
            //Cancel download task
            fileDownloading = false;
            progressBar.dismiss();
            mActivity.finish();
        }

        @Override
        protected void onPreExecute() {
            super.onPreExecute();

            progressBar = new ProgressDialog(mActivity);
            progressBar.setMessage(getResources().getString(R.string.updating_lantern));
            progressBar.setProgressStyle(ProgressDialog.STYLE_HORIZONTAL);
            progressBar.setIndeterminate(false);
            progressBar.setCancelable(true);
            progressBar.setProgress(0);

            String cancel = getResources().getString(R.string.cancel);

            progressBar.setButton(ProgressDialog.BUTTON_NEGATIVE, cancel, this);
            progressBar.show();
        }

        @Override
        protected Boolean doInBackground(String... params) {

            String updateUrl = params[0];

            Log.d(TAG, "Attempting to download update from " + updateUrl);

            boolean shouldProxy = session.shouldProxy();

            try {

                Lantern.Updater.Stub updater = new Lantern.Updater.Stub() {
                    public void PublishProgress(long percentage) {
                        publishProgress(percentage);
                    }
                };

                Lantern.DownloadUpdate(updateUrl,
                        APK_PATH, shouldProxy, updater);

                return true;

            } catch (Exception e) {
                Log.d(TAG, "Error downloading update: " + e.getMessage());
            }
            return false;
        }

        // show an alert when the update fails
        // and mention where the user can download the latest version
        // this also dismisses the current updater activity
        private void displayError() {

            AlertDialog alertDialog = new AlertDialog.Builder(mActivity).create();
            alertDialog.setTitle(context.getString(R.string.error_update));
            alertDialog.setMessage(context.getString(R.string.manual_update));
            alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL, "OK",
                    new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int which) {
                            dialog.dismiss();
                            mActivity.finish();
                        }
                    });
            alertDialog.show();
        }

        /**
         * Updating progress bar
         */
        @Override
        protected void onProgressUpdate(Long... progress) {
            super.onProgressUpdate(progress);
            // setting progress percentage
            if (progress[0] != null) 
                progressBar.setProgress(progress[0].intValue());
        }

        // begin the installation by opening the resulting file
        @Override
        protected void onPostExecute(Boolean result) {
            super.onPostExecute(result);

            progressBar.dismiss();

            // update cancelled by the user
            if (!fileDownloading) {
                finish();
                return;
            }

            if (!result) {
                Log.d(TAG, "Error trying to install Lantern update");
                displayError();
                return;
            }
 
            Log.d(TAG, "About to install new version of Lantern Android");
            File apkFile = new File(APK_PATH);
            if (apkFile == null || !apkFile.isFile()) {
                Log.e(TAG, "Error loading APK; not found at " + APK_PATH);
                displayError();
                return;
            }

            Intent i = new Intent();
            i.setAction(Intent.ACTION_VIEW);
            i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            i.setDataAndType(Uri.fromFile(apkFile), "application/vnd.android.package-archive");

            this.context.startActivity(i);

            mActivity.finish();
        }
    }
}
