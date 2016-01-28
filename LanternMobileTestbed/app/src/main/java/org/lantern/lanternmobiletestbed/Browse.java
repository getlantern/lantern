package org.lantern.lanternmobiletestbed;

import android.os.AsyncTask;
import android.os.Bundle;
import android.support.design.widget.FloatingActionButton;
import android.support.design.widget.Snackbar;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.view.View;
import android.view.Menu;
import android.view.MenuItem;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.ToggleButton;
import android.util.Log;

import go.lantern.Lantern;

public class Browse extends AppCompatActivity {
    private static final String TAG = "Browse";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_browse);
        Toolbar toolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        WebView webView = getWebView();
        WebSettings webSettings = webView.getSettings();
        webSettings.setBuiltInZoomControls(true);
        webSettings.setJavaScriptEnabled(true);
        webView.loadUrl("http://whatismyipaddress.com/");
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
        new AsyncTask<Boolean, Void, Void>() {
            @Override
            protected Void doInBackground(Boolean... params) {
                boolean on = params[0];
                try {
                    if (on) {
                        String addr = Lantern.Start("LanternTestBed", 30000);
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
                    } else {
                        System.clearProperty("http.proxyHost");
                        System.clearProperty("http.proxyPort");
                        System.clearProperty("https.proxyHost");
                        System.clearProperty("https.proxyPort");
                    }
                    return null;
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            }

            @Override
            protected void onPostExecute(Void aVoid) {
                getWebView().reload();
            }
        }.execute(button.isChecked());
    }

    private WebView getWebView() {
        return (WebView) findViewById(R.id.webView);
    }
}
