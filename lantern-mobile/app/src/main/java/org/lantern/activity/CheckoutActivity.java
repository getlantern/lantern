package org.lantern.activity;
 

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.graphics.Bitmap;
import android.support.v4.view.MenuItemCompat;
import android.support.v7.app.ActionBarActivity;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentActivity;
import android.support.v4.view.ActionProvider;
import android.os.Bundle;
import android.text.InputType;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.SubMenu;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;

import org.lantern.R;

public class CheckoutActivity extends FragmentActivity {
    private static String TAG = "CheckoutDemo";
    private static final String mCheckoutUrl = "file:///android_asset/checkout.html";

	private WebView mWebView;
	private WebSettings mWebSettings;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.fragment_checkout);

		Log.d(TAG, "Loading Stripe webview");

		mWebView = (WebView) findViewById(R.id.checkoutWebView);

		mWebSettings = mWebView.getSettings();
		mWebSettings.setJavaScriptEnabled(true);
		mWebSettings.setSupportMultipleWindows(true);
		mWebSettings.setJavaScriptCanOpenWindowsAutomatically(true);

		WebViewClient client = new WebViewClient();
		mWebView.setWebViewClient(client);
		mWebView.loadUrl(mCheckoutUrl);

        //getSupportFragmentManager().beginTransaction()
        //    .add(R.id.container, mCheckoutView)
        //    .commit();
    }
}
