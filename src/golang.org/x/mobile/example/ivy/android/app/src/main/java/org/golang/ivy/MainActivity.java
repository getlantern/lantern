/*
 * Copyright 2015 The Go Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 */

package org.golang.ivy;

import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.text.TextUtils;
import android.util.Log;
import android.util.Pair;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.ScrollView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

/*
 * Main activity that consists of an edit view to accept the expression
 * and a web view to display output of the expression.
 */
public class MainActivity extends AppCompatActivity {
    final String DEMO_SCRIPT = "demo.ivy";  // in assets directory.
    final String DEBUG_TAG = "Ivy";
    final String PROMPT = "> ";

    private WebView mWebView;
    private EditText mEditText;
    private ScrollView mScroller;

    private BufferedReader mDemo;
    private ImageButton mOKButton;  // enabled only in demo mode.

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        mScroller = (ScrollView) findViewById(R.id.scroller);
        mWebView = (WebView) findViewById(R.id.webView);
        mEditText = (EditText) findViewById(R.id.editText);
        mOKButton = (ImageButton) findViewById(R.id.imageButton);
        mOKButton.setVisibility(View.GONE);

        if (savedInstanceState != null) {
            mWebView.restoreState(savedInstanceState);
        } else {
            clear();
        }
        configureWebView(mWebView);

        mEditText.requestFocus();
        mEditText.setOnKeyListener(new View.OnKeyListener() {
            public boolean onKey(View v, int keyCode, KeyEvent event) {
                if ((event.getAction() == KeyEvent.ACTION_DOWN) && (keyCode == KeyEvent.KEYCODE_ENTER)) {
                    callIvy();
                    return true;
                }
                return false;
            }
        });

        mOKButton.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                callIvy();
            }
        });

        /* For webview debugging - visit chrome://inspect/#devices */
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            if (0 != (getApplicationInfo().flags &= ApplicationInfo.FLAG_DEBUGGABLE))
            { WebView.setWebContentsDebuggingEnabled(true); }
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        mWebView.saveState(outState);
        super.onSaveInstanceState(outState);
    }

    public void onRestoreInstanceState(Bundle savedInstanceState) {
        super.onRestoreInstanceState(savedInstanceState);
        mWebView.restoreState(savedInstanceState);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.menu_main, menu);
        return true;
    }

    private long mLastPress = 0;
    @Override
    public void onBackPressed() {
        // TODO: store and restore the state across app restarts.
        long currentTime = System.currentTimeMillis();
        if(currentTime - mLastPress > 6000){
            Toast.makeText(getBaseContext(), "Press back again to exit.\nAll app state will be lost upon exit.", Toast.LENGTH_LONG).show();
            mLastPress = currentTime;
        }else{
            super.onBackPressed();
        }
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        switch (id) {
            case R.id.action_about:
                startActivity(new Intent(this, AboutIvy.class));
                return true;
            case R.id.action_help:
                startActivity(new Intent(this, Help.class));
                return true;
            case R.id.action_clear:
                clear();
                return true;
            case R.id.action_demo:
                loadDemo();
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }

    private void clear() {
        // As described in https://code.google.com/p/android/issues/detail?id=18726
        // clearing the contents of the webview doesn't shrink the webview size in some
        // old versions of Android. (e.g. Moto X running 4.4.4). I tried various techniques
        // suggested in the Internet, but nothing worked except creating a new webview.
        WebView newView = new WebView(this);
        newView.setLayoutParams(mWebView.getLayoutParams());
        newView.setId(R.id.webView);

        configureWebView(newView);

        mScroller.removeView(mWebView);
        mWebView.destroy();

        mWebView = newView;
        mWebView.loadUrl("file:///android_asset/tape.html");
        mWebView.setBackgroundColor(getResources().getColor(R.color.body));
        mScroller.addView(mWebView);

        mEditText.setText("");
        Mobile.Reset();
        unloadDemo();
    }

    void configureWebView(WebView webView) {
        // We enable javascript, but disallow any url loading.
        webView.getSettings().setJavaScriptEnabled(true);
        webView.setWebViewClient(new WebViewClient() {
            // Disallow arbitrary contents loaded into our own webview.
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                view.getContext().startActivity(
                        new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                return true;
            }
        });
        webView.setFocusable(false);
        webView.addOnLayoutChangeListener(new View.OnLayoutChangeListener() {
            @Override
            public void onLayoutChange(View v, int left, int top, int right, int bottom,
                                       int oldLeft, int oldTop, int oldRight, int oldBottom) {
                // It's possible that the layout is not complete.
                // In that case we will get all zero values for the positions. Ignore this case.
                if (left == 0 && top == 0 && right == 0 && bottom == 0) {
                    return;
                }
                scrollToBottom();
            }
        });
    }

    private void appendShowText(final String s, final String tag) {
        mWebView.loadUrl("javascript:appendDiv('" + TextUtils.htmlEncode(s).replaceAll("(\r\n|\n)", "<br />") + "', '" + tag + "')");
        mWebView.setBackgroundColor(getResources().getColor(R.color.body));
    }

    private void callIvy() {
        String s = mEditText.getText().toString().trim();
        if (s != null && !s.isEmpty()) {
            appendShowText(PROMPT + s, "expr");
        }
        new IvyCallTask().execute(s);  // where call to Ivy backend occurs.
    }

    private synchronized void loadDemo() {
        try {
            if (mDemo == null) {
                mDemo = new BufferedReader(new InputStreamReader(getAssets().open(DEMO_SCRIPT), "UTF-8"));
            }
            mOKButton.setVisibility(View.VISIBLE);
            new IvyCallTask().execute("");
        } catch (IOException e) {
            Toast.makeText(this, "Failed to load Demo script.\nContact the app author.", Toast.LENGTH_SHORT);
        }
    }

    private synchronized void unloadDemo() {
        if (mDemo == null) { return; }
        try {
            mDemo.close();
        } catch (IOException e) {
            Log.d(DEBUG_TAG, e.toString());
        }
        mDemo = null;
        mOKButton.setVisibility(View.GONE);
    }

    private synchronized String readDemo() {
        if (mDemo == null) { return null; }
        try {
            return mDemo.readLine();
        } catch (IOException e) {
            unloadDemo();
        }
        return null;
    }

    private void scrollToBottom() {
        mScroller.post(new Runnable() {
            public void run() {
                mScroller.smoothScrollTo(0, mWebView.getBottom());
            }
        });
    }

    // AsyncTask that evaluates the expression (string), and returns the strings
    // to display in the web view and the edit view respectively.
    private class IvyCallTask extends AsyncTask<String, Void, Pair<String, String> > {
        private String ivyEval(final String expr) {
            try {
                // org.golang.ivy.Mobile was generated using
                // gomobile bind -javapkg=org.golang.ivy robpike.io/ivy/mobile
                return Mobile.Eval(expr);  // Gobind-generated method.
            } catch (Exception e) {
                return "error: "+e.getMessage();
            }
        }

        // doInBackground checks the demo script (if the passed-in param is empty),
        // or returns the ivy evaluation result.
        @Override
        protected Pair<String, String> doInBackground(String ...param) {
            final String expr = param[0];
            // TODO: cancel, timeout
            if (expr == null || expr.isEmpty()) {
                return checkDemo();
            }
            return Pair.create(ivyEval(expr), "");
        }

        // checkDemo reads the demo script and returns the comment, and the next expression.
        protected Pair<String, String> checkDemo() {
            String showText = null;
            while (true) {
                String s = readDemo();
                if (s == null) { return Pair.create(showText, null); }

                int sharp = s.indexOf("#");
                if (sharp < 0) {
                    return Pair.create(showText, s);
                }
                s += "\n";
                if (showText == null) {
                    showText = s.substring(sharp, s.length());
                } else {
                    showText += s.substring(sharp, s.length());
                }
                if (sharp > 0) {
                    return Pair.create(s.substring(sharp, s.length()), s.substring(0, sharp));
                }
            }
        }

        @Override
        protected void onPostExecute(final Pair<String, String> result) {
            if (result == null || (result.first == null && result.second == null)) {
                return;
            }
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    String showText = result.first;
                    if (showText != null) {
                        if (showText.startsWith("#")) {
                            appendShowText(showText, "comment");
                        } else {
                            appendShowText(showText, "result");
                        }
                    }
                    String editText = result.second;
                    if (editText != null) {
                        mEditText.setText(editText);
                    }
                }
            });

        }
    }
}
