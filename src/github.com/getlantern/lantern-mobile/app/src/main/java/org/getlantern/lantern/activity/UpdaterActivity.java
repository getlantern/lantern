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
import android.widget.TextView;
import android.widget.Button;
import android.view.View.OnClickListener;

import org.androidannotations.annotations.AfterViews;
import org.androidannotations.annotations.Click;
import org.androidannotations.annotations.EActivity;
import org.androidannotations.annotations.Extra;
import org.androidannotations.annotations.ViewById;

import go.lantern.Lantern;
import org.getlantern.lantern.LanternApp;
import org.getlantern.lantern.model.SessionManager;
import org.getlantern.lantern.R;

import java.io.File;

@EActivity(R.layout.activity_updater)
public class UpdaterActivity extends Activity {

    private static final String TAG = "UpdaterActivity";

    @Extra("updateUrl")
    String updateUrl;

    @ViewById
    Button notNow;

    private UpdaterTask mUpdaterTask;
    private ProgressDialog progressBar;
    private SessionManager session;

    private boolean fileDownloading = false;

    @AfterViews
    void afterViews() {
        session = LanternApp.getSession();
    }

    @Click(R.id.notNow)
    void notNowClicked() {
        finish();
    }

    @Click(R.id.installUpdate)
    void installUpdate() {
        runUpdater();
    }

    private void runUpdater() {

        Log.d(TAG, "Downloading latest version of Lantern from " + updateUrl);
        fileDownloading = true;
        
        String[] updaterParams = {updateUrl};
        mUpdaterTask = new UpdaterTask(this);
        mUpdaterTask.execute(updaterParams);

    }

    public void dismissActivity() {
        finish();
    }

    @Override
    public void finish() {
        super.finish();
    }

    class UpdaterTask extends AsyncTask<String, String, String> {

        private final UpdaterActivity mActivity;
        private final Context context;

        private static final String APK_PATH = "/sdcard/Lantern.apk";

        UpdaterTask(final UpdaterActivity activity) {
            mActivity = activity;
            context = mActivity.getApplicationContext();
        }

        @Override
        protected void onPreExecute() {
            super.onPreExecute();

            progressBar = new ProgressDialog(mActivity);
            progressBar.setMessage("Updating Lantern");
            progressBar.setProgressStyle(ProgressDialog.STYLE_HORIZONTAL);
            progressBar.setIndeterminate(false);
            progressBar.setCancelable(true);
            progressBar.setProgress(0);

            progressBar.setButton(ProgressDialog.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

                @Override
                public void onClick(DialogInterface dialog, int which) {
                    //Cancel download task
                    fileDownloading = false;
                    progressBar.cancel();
                }
            });
            progressBar.show();
        }

        @Override
        protected String doInBackground(String... sUrl) {
            return Lantern.DownloadUpdate(session.startLocalProxy(),
                    sUrl[0],
                    APK_PATH, new Lantern.Updater.Stub() {
                        public void ShowProgress(String percentage) {
                            publishProgress(percentage);
                        }

                        public void DisplayError() {
                            Error();
                        }
            });
        }

        // show an alert when the update fails
        // and mention where the user can download the latest version
        // this also dismisses the current updater activity
        protected void Error() {

            AlertDialog alertDialog = new AlertDialog.Builder(mActivity).create();
            alertDialog.setTitle(context.getString(R.string.error_update));
            alertDialog.setMessage(context.getString(R.string.manual_update));
            alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL, "OK",
                    new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int which) {
                            dialog.dismiss();
                            mActivity.dismissActivity();
                        }
                    });
            alertDialog.show();
        }

        /**
         * Updating progress bar
         */
        @Override
        protected void onProgressUpdate(String... progress) {
            super.onProgressUpdate(progress);
            // setting progress percentage
            progressBar.setProgress(Integer.parseInt(progress[0]));
        }

        // begin the installation by opening the resulting file
        @Override
        protected void onPostExecute(final String path) {
            super.onPostExecute(path);
 
            progressBar.dismiss();
                                      
            if (!fileDownloading) {
                finish();
                return;
            }

            Intent i = new Intent();
            i.setAction(Intent.ACTION_VIEW);
            i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            i.setDataAndType(Uri.fromFile(new File(path)), "application/vnd.android.package-archive");
            Log.d(TAG, "About to install new version of Lantern Android");
            this.context.startActivity(i);

            mActivity.dismissActivity();
        }
    }
}
