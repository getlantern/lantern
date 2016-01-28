package org.lantern.lanternmobiletestbed;

import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.TextView;
import android.widget.ToggleButton;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.InetSocketAddress;
import java.net.Proxy;
import java.net.ProxySelector;
import java.net.SocketAddress;
import java.net.URI;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Scanner;
import java.util.concurrent.atomic.AtomicReference;

import go.lantern.Lantern;

public class Browse extends AppCompatActivity {
    private static final String TAG = "Browse";
    private static final String GEO_LOOKUP = "http://ipinfo.io/ip";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_browse);
        Toolbar toolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        onToggleLantern(findViewById(R.id.toggleButton));
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_browse, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    public void onToggleLantern(View view) {
        ToggleButton button = (ToggleButton) view;
        new AsyncTask<Boolean, Void, String>() {
            @Override
            protected String doInBackground(Boolean... params) {
                boolean on = params[0];
                try {
                    if (on) {
                        Log.i(TAG, "Turning on proxy");
                        String addr = Lantern.Start(new File(getApplicationContext().getFilesDir().getAbsolutePath(), "lantern_LanternMobileTestBed").getAbsolutePath(), 30000);
                        String host = addr.split(":")[0];
                        String port = addr.split(":")[1];
//                        Lantern.On("LanternTestBed",
//                                android.os.Build.DEVICE,
//                                android.os.Build.MODEL,
//                                "" + android.os.Build.VERSION.SDK_INT + " ("  + android.os.Build.VERSION.RELEASE + ")");
                        System.setProperty("http.proxyHost", host);
                        System.setProperty("http.proxyPort", port);
                        System.setProperty("https.proxyHost", host);
                        System.setProperty("https.proxyPort", port);
                        Log.i(TAG, "Turned on proxy to: " + addr);
                    } else {
                        Log.i(TAG, "Turning off proxy");
                        System.clearProperty("http.proxyHost");
                        System.clearProperty("http.proxyPort");
                        System.clearProperty("https.proxyHost");
                        System.clearProperty("https.proxyPort");
                        Log.i(TAG, "Turned off proxy");
                    }

                    Log.i(TAG, "Opening connection to " + GEO_LOOKUP);
                    URL url = new URL(GEO_LOOKUP);
                    HttpURLConnection urlConnection = (HttpURLConnection) url.openConnection();
                    // Need to force closing so that old connections (with old proxy settings) don't get reused.
                    urlConnection.setRequestProperty("Connection", "close");
                    try {
                        InputStream in = new BufferedInputStream(urlConnection.getInputStream());
                        Scanner s = new Scanner(in).useDelimiter("\\A");
                        return s.hasNext() ? s.next() : "";
                    } finally {
                        urlConnection.disconnect();
                        Log.i(TAG, "Finished doing geolookup");
                    }
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            }

            @Override
            protected void onPostExecute(String ipAddress) {
                Log.i(TAG, "Setting IP Address to: " + ipAddress);
                ((TextView) findViewById(R.id.ipAddress)).setText(ipAddress);
            }
        }.execute(button.isChecked());
    }
}
