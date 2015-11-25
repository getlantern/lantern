package org.getlantern.lantern.activity;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Button;
import android.view.Window;
import android.view.View.OnClickListener;
import android.view.View;
import android.view.ViewGroup;

import org.getlantern.lantern.R;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URL;
import java.net.URLConnection;

public class UpdaterActivity extends Activity {

    private static final String TAG = "UpdaterActivity";
    private static final String APK_URL = "http://lantern-android.s3.amazonaws.com/lantern-android-beta.apk";

    private UpdaterTask mUpdaterTask;
    private TextView updateAvailableText;
    private ProgressDialog progressBar;

    private boolean fileDownloading = false;


    @Override
    protected void onCreate(final Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_updater);

        progressBar =new ProgressDialog(this);
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

        addDefaults();
    }

    private void addDefaults() {

        Button btn=(Button) findViewById(R.id.not_now);
        btn.setOnClickListener(new OnClickListener() {

            @Override
            public void onClick(View v) {
                finish();
            }
        });

        btn = (Button)findViewById(R.id.install_update);
        btn.setOnClickListener(new OnClickListener() {

            @Override
            public void onClick(View v) {
                runUpdater();
            }
        });
    }

    private void runUpdater() {
        fileDownloading = true;
        progressBar.show();
        //progressBar.setVisibility(View.VISIBLE);
        
        String[] updaterParams = {APK_URL};
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
        protected String doInBackground(String... sUrl) {
            String path = APK_PATH;

            try {
                Log.d(TAG, "Attempting to download new APK from " + sUrl[0]);
                URL url = new URL(sUrl[0]);
                URLConnection connection = url.openConnection();
                connection.connect();

                int fileLength = connection.getContentLength();

                // download the file
                InputStream input = new BufferedInputStream(url.openStream());
                OutputStream output = new FileOutputStream(path);

                byte data[] = new byte[1024];
                long total = 0;
                int count;
                while (fileDownloading && (count = input.read(data)) != -1) {
                    total += count;
                    int progress = (int) (total * 100 / fileLength);
                    publishProgress(Integer.toString(progress));
                    output.write(data, 0, count);
                }

                output.flush();
                output.close();
                input.close();
            } catch (Exception e) {
                Log.e(TAG, "Error installing new APK..");
                Log.e(TAG, e.getMessage());
                displayInstallError();
            }
            return path;
        }

        // show an alert when the update fails
        // and mention where the user can download the latest version
        // this also dismisses the current updater activity
        protected void displayInstallError() {

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
            // setting progress percentage
            progressBar.setProgress(Integer.parseInt(progress[0]));
        }

        // begin the installation by opening the resulting file
        @Override
        protected void onPostExecute(final String path) {

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
