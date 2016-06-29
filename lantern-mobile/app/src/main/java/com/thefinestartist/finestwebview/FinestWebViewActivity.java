package com.thefinestartist.finestwebview;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.content.res.Configuration;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.PorterDuff;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.VectorDrawable;
import android.net.Uri;
import android.net.UrlQuerySanitizer;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.support.annotation.DrawableRes;
import android.support.design.widget.AppBarLayout;
import android.support.design.widget.CoordinatorLayout;
import android.support.design.widget.Snackbar;
import android.support.graphics.drawable.VectorDrawableCompat;
import android.support.v4.content.ContextCompat;
import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.AppCompatImageButton;
import android.support.v7.widget.Toolbar;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.view.animation.Animation;
import android.view.animation.AnimationUtils;
import android.webkit.DownloadListener;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.nineoldandroids.view.ViewHelper;
import com.thefinestartist.converters.UnitConverter;
import com.thefinestartist.finestwebview.enums.Position;
import com.thefinestartist.finestwebview.helpers.BitmapHelper;
import com.thefinestartist.finestwebview.helpers.ColorHelper;
import com.thefinestartist.finestwebview.helpers.TypefaceHelper;
import com.thefinestartist.finestwebview.helpers.UrlParser;
import com.thefinestartist.finestwebview.listeners.BroadCastManager;
import com.thefinestartist.finestwebview.views.ShadowLayout;
import com.thefinestartist.utils.etc.APILevel;
import com.thefinestartist.utils.service.ClipboardManagerUtil;
import com.thefinestartist.utils.ui.DisplayUtil;
import com.thefinestartist.utils.ui.ViewUtil;

import org.lantern.LanternApp;
import org.lantern.model.ProRequest;     
import org.lantern.model.ProResponse;  
import org.lantern.model.SessionManager;  
import org.lantern.model.Utils;
import org.lantern.activity.WelcomeActivity_;
import org.lantern.R;


/**
 * Created by Leonardo on 11/14/15.
 */
public class FinestWebViewActivity extends AppCompatActivity implements AppBarLayout.OnOffsetChangedListener, ProResponse {

    private static final String TAG = "FinestWebViewActivity";

    private SessionManager session;

    protected int key;

    protected boolean rtl;
    protected int theme;

    protected int statusBarColor;

    protected int toolbarColor;
    protected int toolbarScrollFlags;

    protected int iconDefaultColor;
    protected int iconDisabledColor;
    protected int iconPressedColor;
    protected int iconSelector;

    protected boolean showIconClose;
    protected boolean disableIconClose;
    protected boolean showIconBack;
    protected boolean disableIconBack;
    protected boolean showIconForward;
    protected boolean disableIconForward;
    protected boolean showIconMenu;
    protected boolean disableIconMenu;

    protected boolean showSwipeRefreshLayout;
    protected int swipeRefreshColor;
    protected int[] swipeRefreshColors;

    protected boolean showDivider;
    protected boolean gradientDivider;
    protected int dividerColor;
    protected float dividerHeight;

    protected boolean showProgressBar;
    protected int progressBarColor;
    protected float progressBarHeight;
    protected Position progressBarPosition;

    protected String titleDefault;
    protected boolean updateTitleFromHtml;
    protected float titleSize;
    protected String titleFont;
    protected int titleColor;

    protected boolean showUrl;
    protected float urlSize;
    protected String urlFont;
    protected int urlColor;

    protected int menuColor;
    protected int menuDropShadowColor;
    protected float menuDropShadowSize;
    protected int menuSelector;

    protected float menuTextSize;
    protected String menuTextFont;
    protected int menuTextColor;

    protected int menuTextGravity;
    protected float menuTextPaddingLeft;
    protected float menuTextPaddingRight;

    protected boolean showMenuRefresh;
    protected int stringResRefresh;
    protected boolean showMenuFind;
    protected int stringResFind;
    protected boolean showMenuShareVia;
    protected int stringResShareVia;
    protected boolean showMenuCopyLink;
    protected int stringResCopyLink;
    protected boolean showMenuOpenWith;
    protected int stringResOpenWith;

    protected int animationCloseEnter;
    protected int animationCloseExit;

    protected boolean backPressToClose;
    protected int stringResCopiedToClipboard;

    protected Boolean webViewSupportZoom;
    protected Boolean webViewMediaPlaybackRequiresUserGesture;
    protected Boolean webViewBuiltInZoomControls;
    protected Boolean webViewDisplayZoomControls;
    protected Boolean webViewAllowFileAccess;
    protected Boolean webViewAllowContentAccess;
    protected Boolean webViewLoadWithOverviewMode;
    protected Boolean webViewSaveFormData;
    protected Integer webViewTextZoom;
    protected Boolean webViewUseWideViewPort;
    protected Boolean webViewSupportMultipleWindows;
    protected WebSettings.LayoutAlgorithm webViewLayoutAlgorithm;
    protected String webViewStandardFontFamily;
    protected String webViewFixedFontFamily;
    protected String webViewProxyAddr;
    protected Boolean webViewInsideScrollStyle;
    protected WebViewClient webViewClient;
    protected String webViewSansSerifFontFamily;
    protected String webViewSerifFontFamily;
    protected String webViewCursiveFontFamily;
    protected String webViewFantasyFontFamily;
    protected Integer webViewMinimumFontSize;
    protected Integer webViewMinimumLogicalFontSize;
    protected Integer webViewDefaultFontSize;
    protected Integer webViewDefaultFixedFontSize;
    protected Boolean webViewLoadsImagesAutomatically;
    protected Boolean webViewBlockNetworkImage;
    protected Boolean webViewBlockNetworkLoads;
    protected Boolean webViewJavaScriptEnabled;
    protected Boolean webViewAllowUniversalAccessFromFileURLs;
    protected Boolean webViewAllowFileAccessFromFileURLs;
    protected String webViewGeolocationDatabasePath;
    protected Boolean webViewAppCacheEnabled;
    protected String webViewAppCachePath;
    protected Boolean webViewDatabaseEnabled;
    protected Boolean webViewDomStorageEnabled;
    protected Boolean webViewGeolocationEnabled;
    protected Boolean webViewJavaScriptCanOpenWindowsAutomatically;
    protected String webViewDefaultTextEncodingName;
    protected String webViewUserAgentString;
    protected Boolean webViewNeedInitialFocus;
    protected Integer webViewCacheMode;
    protected Integer webViewMixedContentMode;
    protected Boolean webViewOffscreenPreRaster;

    protected String injectJavaScript;

    protected String mimeType;
    protected String encoding;
    protected String data;
    protected String url;

    protected void getOptions() {
        Intent intent = getIntent();
        if (intent == null)
            return;

        TypedValue typedValue = new TypedValue();
        TypedArray a = obtainStyledAttributes(typedValue.data, new int[]{
                R.attr.colorPrimaryDark,
                R.attr.colorPrimary,
                R.attr.colorAccent,
                android.R.attr.textColorPrimary,
                android.R.attr.textColorSecondary,
                android.R.attr.selectableItemBackground,
                android.R.attr.selectableItemBackgroundBorderless});
        int colorPrimaryDark = a.getColor(0, ContextCompat.getColor(this, R.color.finestGray));
        int colorPrimary = a.getColor(1, ContextCompat.getColor(this, R.color.finestWhite));
        int colorAccent = a.getColor(2, ContextCompat.getColor(this, R.color.finestBlack));
        int textColorPrimary = a.getColor(3, ContextCompat.getColor(this, R.color.finestBlack));
        int textColorSecondary = a.getColor(4, ContextCompat.getColor(this, R.color.finestSilver));
        int selectableItemBackground = Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB ?
                a.getResourceId(5, 0) : R.drawable.selector_light_theme;
        int selectableItemBackgroundBorderless = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP ?
                a.getResourceId(6, 0) : R.drawable.selector_light_theme;
        a.recycle();

        FinestWebView.Builder builder = (FinestWebView.Builder) intent.getSerializableExtra("builder");

        key = builder.key;

        rtl = builder.rtl != null ? builder.rtl : getResources().getBoolean(R.bool.is_right_to_left);
        theme = builder.theme != null ? builder.theme : 0;

        statusBarColor = builder.statusBarColor != null ? builder.statusBarColor : colorPrimaryDark;

        toolbarColor = builder.toolbarColor != null ? builder.toolbarColor : colorPrimary;
        toolbarScrollFlags = builder.toolbarScrollFlags != null ?
                builder.toolbarScrollFlags :
                AppBarLayout.LayoutParams.SCROLL_FLAG_SCROLL | AppBarLayout.LayoutParams.SCROLL_FLAG_ENTER_ALWAYS;

        iconDefaultColor = builder.iconDefaultColor != null ? builder.iconDefaultColor : colorAccent;
        iconDisabledColor = builder.iconDisabledColor != null ? builder.iconDisabledColor : ColorHelper.disableColor(iconDefaultColor);
        iconPressedColor = builder.iconPressedColor != null ? builder.iconPressedColor : iconDefaultColor;
        iconSelector = builder.iconSelector != null ? builder.iconSelector : selectableItemBackgroundBorderless;

        showIconClose = builder.showIconClose != null ? builder.showIconClose : true;
        disableIconClose = builder.disableIconClose != null ? builder.disableIconClose : false;
        showIconBack = builder.showIconBack != null ? builder.showIconBack : true;
        disableIconBack = builder.disableIconBack != null ? builder.disableIconBack : false;
        showIconForward = builder.showIconForward != null ? builder.showIconForward : true;
        disableIconForward = builder.disableIconForward != null ? builder.disableIconForward : false;
        showIconMenu = builder.showIconMenu != null ? builder.showIconMenu : true;
        disableIconMenu = builder.disableIconMenu != null ? builder.disableIconMenu : false;

        showSwipeRefreshLayout = builder.showSwipeRefreshLayout != null ? builder.showSwipeRefreshLayout : true;
        swipeRefreshColor = builder.swipeRefreshColor != null ? builder.swipeRefreshColor : colorAccent;
        if (builder.swipeRefreshColors != null) {
            int[] colors = new int[builder.swipeRefreshColors.length];
            for (int i = 0; i < builder.swipeRefreshColors.length; i++)
                colors[i] = builder.swipeRefreshColors[i];
            swipeRefreshColors = colors;
        }

        showDivider = builder.showDivider != null ? builder.showDivider : true;
        gradientDivider = builder.gradientDivider != null ? builder.gradientDivider : true;
        dividerColor = builder.dividerColor != null ? builder.dividerColor : ContextCompat.getColor(this, R.color.finestBlack10);
        dividerHeight = builder.dividerHeight != null ? builder.dividerHeight : getResources().getDimension(R.dimen.defaultDividerHeight);

        showProgressBar = builder.showProgressBar != null ? builder.showProgressBar : true;
        progressBarColor = builder.progressBarColor != null ? builder.progressBarColor : colorAccent;
        progressBarHeight = builder.progressBarHeight != null ? builder.progressBarHeight : getResources().getDimension(R.dimen.defaultProgressBarHeight);
        progressBarPosition = builder.progressBarPosition != null ? builder.progressBarPosition : Position.BOTTON_OF_TOOLBAR;

        titleDefault = builder.titleDefault;
        updateTitleFromHtml = builder.updateTitleFromHtml != null ? builder.updateTitleFromHtml : true;
        titleSize = builder.titleSize != null ? builder.titleSize : getResources().getDimension(R.dimen.defaultTitleSize);
        titleFont = builder.titleFont != null ? builder.titleFont : "Roboto-Medium.ttf";
        titleColor = builder.titleColor != null ? builder.titleColor : textColorPrimary;

        showUrl = builder.showUrl != null ? builder.showUrl : true;
        urlSize = builder.urlSize != null ? builder.urlSize : getResources().getDimension(R.dimen.defaultUrlSize);
        urlFont = builder.urlFont != null ? builder.urlFont : "Roboto-Regular.ttf";
        urlColor = builder.urlColor != null ? builder.urlColor : textColorSecondary;

        menuColor = builder.menuColor != null ? builder.menuColor : ContextCompat.getColor(this, R.color.finestWhite);
        menuDropShadowColor = builder.menuDropShadowColor != null ? builder.menuDropShadowColor : ContextCompat.getColor(this, R.color.finestBlack10);
        menuDropShadowSize = builder.menuDropShadowSize != null ? builder.menuDropShadowSize : getResources().getDimension(R.dimen.defaultMenuDropShadowSize);
        menuSelector = builder.menuSelector != null ? builder.menuSelector : selectableItemBackground;

        menuTextSize = builder.menuTextSize != null ? builder.menuTextSize : getResources().getDimension(R.dimen.defaultMenuTextSize);
        menuTextFont = builder.menuTextFont != null ? builder.menuTextFont : "Roboto-Regular.ttf";
        menuTextColor = builder.menuTextColor != null ? builder.menuTextColor : ContextCompat.getColor(this, R.color.finestBlack);

        menuTextGravity = builder.menuTextGravity != null ? builder.menuTextGravity : Gravity.CENTER_VERTICAL | Gravity.START;
        menuTextPaddingLeft = builder.menuTextPaddingLeft != null ? builder.menuTextPaddingLeft :
                rtl ? getResources().getDimension(R.dimen.defaultMenuTextPaddingRight) : getResources().getDimension(R.dimen.defaultMenuTextPaddingLeft);
        menuTextPaddingRight = builder.menuTextPaddingRight != null ? builder.menuTextPaddingRight :
                rtl ? getResources().getDimension(R.dimen.defaultMenuTextPaddingLeft) : getResources().getDimension(R.dimen.defaultMenuTextPaddingRight);

        showMenuRefresh = builder.showMenuRefresh != null ? builder.showMenuRefresh : true;
        stringResRefresh = builder.stringResRefresh != null ? builder.stringResRefresh : R.string.refresh;
        showMenuFind = builder.showMenuFind != null ? builder.showMenuFind : false;
        stringResFind = builder.stringResFind != null ? builder.stringResFind : R.string.find;
        showMenuShareVia = builder.showMenuShareVia != null ? builder.showMenuShareVia : true;
        stringResShareVia = builder.stringResShareVia != null ? builder.stringResShareVia : R.string.share_via;
        showMenuCopyLink = builder.showMenuCopyLink != null ? builder.showMenuCopyLink : true;
        stringResCopyLink = builder.stringResCopyLink != null ? builder.stringResCopyLink : R.string.copy_link;
        showMenuOpenWith = builder.showMenuOpenWith != null ? builder.showMenuOpenWith : true;
        stringResOpenWith = builder.stringResOpenWith != null ? builder.stringResOpenWith : R.string.open_with;

        animationCloseEnter = builder.animationCloseEnter != null ? builder.animationCloseEnter : R.anim.modal_activity_close_enter;
        animationCloseExit = builder.animationCloseExit != null ? builder.animationCloseExit : R.anim.modal_activity_close_exit;

        backPressToClose = builder.backPressToClose != null ? builder.backPressToClose : false;
        stringResCopiedToClipboard = builder.stringResCopiedToClipboard != null ? builder.stringResCopiedToClipboard : R.string.copied_to_clipboard;

        webViewSupportZoom = builder.webViewSupportZoom;
        webViewMediaPlaybackRequiresUserGesture = builder.webViewMediaPlaybackRequiresUserGesture;
        webViewBuiltInZoomControls = builder.webViewBuiltInZoomControls != null ? builder.webViewBuiltInZoomControls : false;
        webViewDisplayZoomControls = builder.webViewDisplayZoomControls != null ? builder.webViewDisplayZoomControls : false;
        webViewAllowFileAccess = builder.webViewAllowFileAccess != null ? builder.webViewAllowFileAccess : true;
        webViewAllowContentAccess = builder.webViewAllowContentAccess;
        webViewLoadWithOverviewMode = builder.webViewLoadWithOverviewMode != null ? builder.webViewLoadWithOverviewMode : true;
        webViewSaveFormData = builder.webViewSaveFormData;
        webViewTextZoom = builder.webViewTextZoom;
        webViewUseWideViewPort = builder.webViewUseWideViewPort;
        webViewSupportMultipleWindows = builder.webViewSupportMultipleWindows;
        webViewLayoutAlgorithm = builder.webViewLayoutAlgorithm;
        webViewStandardFontFamily = builder.webViewStandardFontFamily;
        webViewFixedFontFamily = builder.webViewFixedFontFamily;
        webViewProxyAddr = builder.webViewProxyAddr;
        webViewClient    = builder.webViewClient;
        webViewSansSerifFontFamily = builder.webViewSansSerifFontFamily;
        webViewSerifFontFamily = builder.webViewSerifFontFamily;
        webViewCursiveFontFamily = builder.webViewCursiveFontFamily;
        webViewFantasyFontFamily = builder.webViewFantasyFontFamily;
        webViewMinimumFontSize = builder.webViewMinimumFontSize;
        webViewMinimumLogicalFontSize = builder.webViewMinimumLogicalFontSize;
        webViewDefaultFontSize = builder.webViewDefaultFontSize;
        webViewDefaultFixedFontSize = builder.webViewDefaultFixedFontSize;
        webViewLoadsImagesAutomatically = builder.webViewLoadsImagesAutomatically;
        webViewBlockNetworkImage = builder.webViewBlockNetworkImage;
        webViewBlockNetworkLoads = builder.webViewBlockNetworkLoads;
        webViewJavaScriptEnabled = builder.webViewJavaScriptEnabled != null ? builder.webViewJavaScriptEnabled : true;
        webViewAllowUniversalAccessFromFileURLs = builder.webViewAllowUniversalAccessFromFileURLs;
        webViewAllowFileAccessFromFileURLs = builder.webViewAllowFileAccessFromFileURLs;
        webViewGeolocationDatabasePath = builder.webViewGeolocationDatabasePath;
        webViewAppCacheEnabled = builder.webViewAppCacheEnabled != null ? builder.webViewAppCacheEnabled : true;
        webViewAppCachePath = builder.webViewAppCachePath;
        webViewDatabaseEnabled = builder.webViewDatabaseEnabled;
        webViewDomStorageEnabled = builder.webViewDomStorageEnabled != null ? builder.webViewDomStorageEnabled : true;
        webViewGeolocationEnabled = builder.webViewGeolocationEnabled;
        webViewJavaScriptCanOpenWindowsAutomatically = builder.webViewJavaScriptCanOpenWindowsAutomatically;
        webViewDefaultTextEncodingName = builder.webViewDefaultTextEncodingName;
        webViewUserAgentString = builder.webViewUserAgentString;
        webViewNeedInitialFocus = builder.webViewNeedInitialFocus;
        webViewCacheMode = builder.webViewCacheMode;
        webViewMixedContentMode = builder.webViewMixedContentMode;
        webViewOffscreenPreRaster = builder.webViewOffscreenPreRaster;

        injectJavaScript = builder.injectJavaScript;

        mimeType = builder.mimeType;
        encoding = builder.encoding;
        data = builder.data;
        url = builder.url;
    }

    protected CoordinatorLayout coordinatorLayout;

    protected AppBarLayout appBar;
    protected Toolbar toolbar;
    protected RelativeLayout toolbarLayout;

    protected TextView title;
    protected TextView urlTv;

    protected AppCompatImageButton close;
    protected AppCompatImageButton back;
    protected AppCompatImageButton forward;
    protected AppCompatImageButton more;

    protected SwipeRefreshLayout swipeRefreshLayout;
    protected WebView webView;

    protected View gradient;
    protected View divider;
    protected ProgressBar progressBar;

    protected RelativeLayout menuLayout;
    protected ShadowLayout shadowLayout;
    protected LinearLayout menuBackground;

    protected LinearLayout menuRefresh;
    protected TextView menuRefreshTv;
    protected LinearLayout menuFind;
    protected TextView menuFindTv;
    protected LinearLayout menuShareVia;
    protected TextView menuShareViaTv;
    protected LinearLayout menuCopyLink;
    protected TextView menuCopyLinkTv;
    protected LinearLayout menuOpenWith;
    protected TextView menuOpenWithTv;

    protected FrameLayout webLayout;

    protected void bindViews() {
        coordinatorLayout = (CoordinatorLayout) findViewById(R.id.coordinatorLayout);

        appBar = (AppBarLayout) findViewById(R.id.appBar);
        toolbar = (Toolbar) findViewById(R.id.toolbar);
        toolbarLayout = (RelativeLayout) findViewById(R.id.toolbarLayout);

        title = (TextView) findViewById(R.id.title);
        urlTv = (TextView) findViewById(R.id.url);

        close = (AppCompatImageButton) findViewById(R.id.close);
        back = (AppCompatImageButton) findViewById(R.id.back);
        forward = (AppCompatImageButton) findViewById(R.id.forward);
        more = (AppCompatImageButton) findViewById(R.id.more);

        swipeRefreshLayout = (SwipeRefreshLayout) findViewById(R.id.swipeRefreshLayout);

        gradient = findViewById(R.id.gradient);
        divider = findViewById(R.id.divider);
        progressBar = (ProgressBar) findViewById(R.id.progressBar);

        menuLayout = (RelativeLayout) findViewById(R.id.menuLayout);
        shadowLayout = (ShadowLayout) findViewById(R.id.shadowLayout);
        menuBackground = (LinearLayout) findViewById(R.id.menuBackground);

        menuRefresh = (LinearLayout) findViewById(R.id.menuRefresh);
        menuRefreshTv = (TextView) findViewById(R.id.menuRefreshTv);
        menuFind = (LinearLayout) findViewById(R.id.menuFind);
        menuFindTv = (TextView) findViewById(R.id.menuFindTv);
        menuShareVia = (LinearLayout) findViewById(R.id.menuShareVia);
        menuShareViaTv = (TextView) findViewById(R.id.menuShareViaTv);
        menuCopyLink = (LinearLayout) findViewById(R.id.menuCopyLink);
        menuCopyLinkTv = (TextView) findViewById(R.id.menuCopyLinkTv);
        menuOpenWith = (LinearLayout) findViewById(R.id.menuOpenWith);
        menuOpenWithTv = (TextView) findViewById(R.id.menuOpenWithTv);

        webLayout = (FrameLayout) findViewById(R.id.webLayout);
        webView = new WebView(this);

        if (webViewProxyAddr != null && !webViewProxyAddr.equals("")) {
            Log.d(TAG, "WebViewProxyAddr is " + webViewProxyAddr);
            String[] parts = webViewProxyAddr.split(":");
            String proxyHost = parts[0];
            int proxyPort = Integer.parseInt(parts[1]);
            Log.d(TAG, String.format("WebViewProxyAddr is host (%s) and port (%d)", proxyHost, proxyPort));
            ProxySettings.setProxy(getApplicationContext(),
                    webView, proxyHost, proxyPort);
        }

        webLayout.addView(webView);
    }

    protected void layoutViews() {
        setSupportActionBar(toolbar);

        { // AppBar
            float toolbarHeight = getResources().getDimension(R.dimen.toolbarHeight);
            if (!gradientDivider)
                toolbarHeight += dividerHeight;
            CoordinatorLayout.LayoutParams params = new CoordinatorLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (int) toolbarHeight);
            appBar.setLayoutParams(params);
            coordinatorLayout.requestLayout();
        }

        { // Toolbar
            float toolbarHeight = getResources().getDimension(R.dimen.toolbarHeight);
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (int) toolbarHeight);
            toolbarLayout.setMinimumHeight((int) toolbarHeight);
            toolbarLayout.setLayoutParams(params);
            coordinatorLayout.requestLayout();
        }

        { // TextViews
            int maxWidth = getMaxWidth();
            title.setMaxWidth(maxWidth);
            urlTv.setMaxWidth(maxWidth);
            requestCenterLayout();
        }

        { // Icons
            updateIcon(close, rtl ? R.drawable.more : R.drawable.close);
            updateIcon(back, R.drawable.back);
            updateIcon(forward, R.drawable.forward);
            updateIcon(more, rtl ? R.drawable.close : R.drawable.more);
        }

        { // Divider
            if (gradientDivider) {
                float toolbarHeight = getResources().getDimension(R.dimen.toolbarHeight);
                CoordinatorLayout.LayoutParams params = (CoordinatorLayout.LayoutParams) gradient.getLayoutParams();
                params.setMargins(0, (int) toolbarHeight, 0, 0);
                gradient.setLayoutParams(params);
            }
        }

        { // ProgressBar
            progressBar.setMinimumHeight((int) progressBarHeight);
            CoordinatorLayout.LayoutParams params = new CoordinatorLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    (int) progressBarHeight
            );
            float toolbarHeight = getResources().getDimension(R.dimen.toolbarHeight);
            switch (progressBarPosition) {
                case TOP_OF_TOOLBAR:
                    params.setMargins(0, 0, 0, 0);
                    break;
                case BOTTON_OF_TOOLBAR:
                    params.setMargins(0, (int) toolbarHeight - (int) progressBarHeight, 0, 0);
                    break;
                case TOP_OF_WEBVIEW:
                    params.setMargins(0, (int) toolbarHeight, 0, 0);
                    break;
                case BOTTOM_OF_WEBVIEW:
                    params.setMargins(0, DisplayUtil.getHeight() - (int) progressBarHeight, 0, 0);
                    break;
            }
            progressBar.setLayoutParams(params);
        }

        { // WebLayout
            float toolbarHeight = getResources().getDimension(R.dimen.toolbarHeight);
            int statusBarHeight = DisplayUtil.getStatusBarHeight();
            int screenHeight = DisplayUtil.getHeight();
            float webLayoutMinimumHeight = screenHeight - toolbarHeight - statusBarHeight;
            if (showDivider && !gradientDivider) webLayoutMinimumHeight -= dividerHeight;
            webLayout.setMinimumHeight((int) webLayoutMinimumHeight);
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    protected void initializeViews() {
        setSupportActionBar(toolbar);

        { // StatusBar
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                Window window = getWindow();
                window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
                window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
                window.setStatusBarColor(statusBarColor);
            }
        }

        { // AppBar
            appBar.addOnOffsetChangedListener(this);
        }

        { // Toolbar
            toolbar.setBackgroundColor(toolbarColor);
            AppBarLayout.LayoutParams params = (AppBarLayout.LayoutParams) toolbar.getLayoutParams();
            params.setScrollFlags(toolbarScrollFlags);
            toolbar.setLayoutParams(params);
        }

        { // TextViews
            title.setText(titleDefault);
            title.setTextSize(TypedValue.COMPLEX_UNIT_PX, titleSize);
            title.setTypeface(TypefaceHelper.get(this, titleFont));
            title.setTextColor(titleColor);

            urlTv.setVisibility(showUrl ? View.VISIBLE : View.GONE);
            urlTv.setText(UrlParser.getHost(url));
            urlTv.setTextSize(TypedValue.COMPLEX_UNIT_PX, urlSize);
            urlTv.setTypeface(TypefaceHelper.get(this, urlFont));
            urlTv.setTextColor(urlColor);

            requestCenterLayout();
        }

        { // Icons
            close.setBackgroundResource(iconSelector);
            back.setBackgroundResource(iconSelector);
            forward.setBackgroundResource(iconSelector);
            more.setBackgroundResource(iconSelector);

            close.setVisibility(showIconClose ? View.VISIBLE : View.GONE);
            close.setEnabled(!disableIconClose);

            if ((showMenuRefresh || showMenuFind || showMenuShareVia || showMenuCopyLink || showMenuOpenWith) && showIconMenu)
                more.setVisibility(View.VISIBLE);
            else
                more.setVisibility(View.GONE);
            more.setEnabled(!disableIconMenu);
        }

        { // WebView
            if (webViewClient != null) {
                webView.setWebViewClient(webViewClient);
            } else {
                webView.setWebViewClient(new MyWebViewClient());
            }

            webView.setWebChromeClient(new MyWebChromeClient());
            webView.setDownloadListener(downloadListener);

            WebSettings settings = webView.getSettings();

            if (webViewSupportZoom != null)
                settings.setSupportZoom(webViewSupportZoom);
            if (webViewMediaPlaybackRequiresUserGesture != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1)
                settings.setMediaPlaybackRequiresUserGesture(webViewMediaPlaybackRequiresUserGesture);
            if (webViewBuiltInZoomControls != null) {
                settings.setBuiltInZoomControls(webViewBuiltInZoomControls);

                if (webViewBuiltInZoomControls) {
                    // Remove NestedScrollView to enable BuiltInZoomControls
                    ((ViewGroup) webView.getParent()).removeAllViews();
                    swipeRefreshLayout.addView(webView);
                    swipeRefreshLayout.removeViewAt(1);
                }
            }
            if (webViewDisplayZoomControls != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB)
                settings.setDisplayZoomControls(webViewDisplayZoomControls);

            if (webViewAllowFileAccess != null)
                settings.setAllowFileAccess(webViewAllowFileAccess);
            if (webViewAllowContentAccess != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB)
                settings.setAllowContentAccess(webViewAllowContentAccess);
            if (webViewLoadWithOverviewMode != null)
                settings.setLoadWithOverviewMode(webViewLoadWithOverviewMode);
            if (webViewSaveFormData != null)
                settings.setSaveFormData(webViewSaveFormData);
            if (webViewTextZoom != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.ICE_CREAM_SANDWICH)
                settings.setTextZoom(webViewTextZoom);
            if (webViewUseWideViewPort != null)
                settings.setUseWideViewPort(webViewUseWideViewPort);
            if (webViewSupportMultipleWindows != null)
                settings.setSupportMultipleWindows(webViewSupportMultipleWindows);
            if (webViewLayoutAlgorithm != null)
                settings.setLayoutAlgorithm(webViewLayoutAlgorithm);
            if (webViewStandardFontFamily != null)
                settings.setStandardFontFamily(webViewStandardFontFamily);
            if (webViewFixedFontFamily != null)
                settings.setFixedFontFamily(webViewFixedFontFamily);
            if (webViewSansSerifFontFamily != null)
                settings.setSansSerifFontFamily(webViewSansSerifFontFamily);
            if (webViewSerifFontFamily != null)
                settings.setSerifFontFamily(webViewSerifFontFamily);
            if (webViewCursiveFontFamily != null)
                settings.setCursiveFontFamily(webViewCursiveFontFamily);
            if (webViewFantasyFontFamily != null)
                settings.setFantasyFontFamily(webViewFantasyFontFamily);
            if (webViewMinimumFontSize != null)
                settings.setMinimumFontSize(webViewMinimumFontSize);
            if (webViewMinimumLogicalFontSize != null)
                settings.setMinimumLogicalFontSize(webViewMinimumLogicalFontSize);
            if (webViewDefaultFontSize != null)
                settings.setDefaultFontSize(webViewDefaultFontSize);
            if (webViewDefaultFixedFontSize != null)
                settings.setDefaultFixedFontSize(webViewDefaultFixedFontSize);
            if (webViewLoadsImagesAutomatically != null)
                settings.setLoadsImagesAutomatically(webViewLoadsImagesAutomatically);
            if (webViewBlockNetworkImage != null)
                settings.setBlockNetworkImage(webViewBlockNetworkImage);
            if (webViewBlockNetworkLoads != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.FROYO)
                settings.setBlockNetworkLoads(webViewBlockNetworkLoads);
            if (webViewJavaScriptEnabled != null)
                settings.setJavaScriptEnabled(webViewJavaScriptEnabled);
            if (webViewAllowUniversalAccessFromFileURLs != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN)
                settings.setAllowUniversalAccessFromFileURLs(webViewAllowUniversalAccessFromFileURLs);
            if (webViewAllowFileAccessFromFileURLs != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN)
                settings.setAllowFileAccessFromFileURLs(webViewAllowFileAccessFromFileURLs);
            if (webViewGeolocationDatabasePath != null)
                settings.setGeolocationDatabasePath(webViewGeolocationDatabasePath);
            if (webViewAppCacheEnabled != null)
                settings.setAppCacheEnabled(webViewAppCacheEnabled);
            if (webViewAppCachePath != null)
                settings.setAppCachePath(webViewAppCachePath);
            if (webViewDatabaseEnabled != null)
                settings.setDatabaseEnabled(webViewDatabaseEnabled);
            if (webViewDomStorageEnabled != null)
                settings.setDomStorageEnabled(webViewDomStorageEnabled);
            if (webViewGeolocationEnabled != null)
                settings.setGeolocationEnabled(webViewGeolocationEnabled);
            if (webViewJavaScriptCanOpenWindowsAutomatically != null)
                settings.setJavaScriptCanOpenWindowsAutomatically(webViewJavaScriptCanOpenWindowsAutomatically);
            if (webViewDefaultTextEncodingName != null)
                settings.setDefaultTextEncodingName(webViewDefaultTextEncodingName);
            if (webViewUserAgentString != null)
                settings.setUserAgentString(webViewUserAgentString);
            if (webViewNeedInitialFocus != null)
                settings.setNeedInitialFocus(webViewNeedInitialFocus);
            if (webViewCacheMode != null)
                settings.setCacheMode(webViewCacheMode);
            if (webViewMixedContentMode != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
                settings.setMixedContentMode(webViewMixedContentMode);
            if (webViewOffscreenPreRaster != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                settings.setOffscreenPreRaster(webViewOffscreenPreRaster);


            if (webViewInsideScrollStyle != null) {
                webView.setScrollBarStyle(View.SCROLLBARS_INSIDE_OVERLAY);
            }

//            // Other webview options
//            webView.setScrollBarStyle(WebView.SCROLLBARS_OUTSIDE_OVERLAY);
//            webView.setScrollbarFadingEnabled(false);
//            //Additional Webview Properties
//            webView.setSoundEffectsEnabled(true);
//            webView.setHorizontalFadingEdgeEnabled(false);
//            webView.setKeepScreenOn(true);
//            webView.setScrollbarFadingEnabled(true);
//            webView.setVerticalFadingEdgeEnabled(false);

            if (data != null)
                webView.loadData(data, mimeType, encoding);
            else if (url != null)
                webView.loadUrl(url);
        }

        { // SwipeRefreshLayout
            swipeRefreshLayout.setEnabled(showSwipeRefreshLayout);
            if (showSwipeRefreshLayout) {
                swipeRefreshLayout.post(new Runnable() {
                    @Override
                    public void run() {
                        swipeRefreshLayout.setRefreshing(true);
                    }
                });
            }

            if (swipeRefreshColors == null)
                swipeRefreshLayout.setColorSchemeColors(swipeRefreshColor);
            else swipeRefreshLayout.setColorSchemeColors(swipeRefreshColors);

            swipeRefreshLayout.setOnRefreshListener(new SwipeRefreshLayout.OnRefreshListener() {
                @Override
                public void onRefresh() {
                    webView.reload();
                }
            });
        }

        { // Divider
            gradient.setVisibility(showDivider && gradientDivider ? View.VISIBLE : View.GONE);
            divider.setVisibility(showDivider && !gradientDivider ? View.VISIBLE : View.GONE);
            if (gradientDivider) {
                int dividerWidth = DisplayUtil.getWidth();
                Bitmap bitmap = BitmapHelper.getGradientBitmap(dividerWidth, (int) dividerHeight, dividerColor);
                BitmapDrawable drawable = new BitmapDrawable(getResources(), bitmap);
                ViewUtil.setBackground(gradient, drawable);

                CoordinatorLayout.LayoutParams params = (CoordinatorLayout.LayoutParams) gradient.getLayoutParams();
                params.height = (int) dividerHeight;
                gradient.setLayoutParams(params);
            } else {
                divider.setBackgroundColor(dividerColor);

                LinearLayout.LayoutParams params = (LinearLayout.LayoutParams) divider.getLayoutParams();
                params.height = (int) dividerHeight;
                divider.setLayoutParams(params);
            }
        }

        { // ProgressBar
            progressBar.setVisibility(showProgressBar ? View.VISIBLE : View.GONE);
            progressBar.getProgressDrawable().setColorFilter(progressBarColor, PorterDuff.Mode.SRC_IN);
            progressBar.setMinimumHeight((int) progressBarHeight);
            CoordinatorLayout.LayoutParams params = new CoordinatorLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    (int) progressBarHeight
            );
            float toolbarHeight = getResources().getDimension(R.dimen.toolbarHeight);
            switch (progressBarPosition) {
                case TOP_OF_TOOLBAR:
                    params.setMargins(0, 0, 0, 0);
                    break;
                case BOTTON_OF_TOOLBAR:
                    params.setMargins(0, (int) toolbarHeight - (int) progressBarHeight, 0, 0);
                    break;
                case TOP_OF_WEBVIEW:
                    params.setMargins(0, (int) toolbarHeight, 0, 0);
                    break;
                case BOTTOM_OF_WEBVIEW:
                    params.setMargins(0, DisplayUtil.getHeight() - (int) progressBarHeight, 0, 0);
                    break;
            }
            progressBar.setLayoutParams(params);
        }

        { // Menu
            GradientDrawable drawable = new GradientDrawable();
            drawable.setCornerRadius(getResources().getDimension(R.dimen.defaultMenuCornerRadius));
            drawable.setColor(menuColor);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN)
                menuBackground.setBackground(drawable);
            else
                menuBackground.setBackgroundDrawable(drawable);

            shadowLayout.setShadowColor(menuDropShadowColor);
            shadowLayout.setShadowSize(menuDropShadowSize);

            RelativeLayout.LayoutParams params = new RelativeLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            int margin = (int) (getResources().getDimension(R.dimen.defaultMenuLayoutMargin) - menuDropShadowSize);
            params.setMargins(0, margin, margin, 0);
            params.addRule(RelativeLayout.ALIGN_PARENT_TOP);
            params.addRule(rtl ? RelativeLayout.ALIGN_PARENT_LEFT : RelativeLayout.ALIGN_PARENT_RIGHT);
            shadowLayout.setLayoutParams(params);

            menuRefresh.setVisibility(showMenuRefresh ? View.VISIBLE : View.GONE);
            menuRefresh.setBackgroundResource(menuSelector);
            menuRefresh.setGravity(menuTextGravity);
            menuRefreshTv.setText(stringResRefresh);
            menuRefreshTv.setTextSize(TypedValue.COMPLEX_UNIT_PX, menuTextSize);
            menuRefreshTv.setTypeface(TypefaceHelper.get(this, menuTextFont));
            menuRefreshTv.setTextColor(menuTextColor);
            menuRefreshTv.setPadding((int) menuTextPaddingLeft, 0, (int) menuTextPaddingRight, 0);

            menuFind.setVisibility(showMenuFind ? View.VISIBLE : View.GONE);
            menuFind.setBackgroundResource(menuSelector);
            menuFind.setGravity(menuTextGravity);
            menuFindTv.setText(stringResFind);
            menuFindTv.setTextSize(TypedValue.COMPLEX_UNIT_PX, menuTextSize);
            menuFindTv.setTypeface(TypefaceHelper.get(this, menuTextFont));
            menuFindTv.setTextColor(menuTextColor);
            menuFindTv.setPadding((int) menuTextPaddingLeft, 0, (int) menuTextPaddingRight, 0);

            menuShareVia.setVisibility(showMenuShareVia ? View.VISIBLE : View.GONE);
            menuShareVia.setBackgroundResource(menuSelector);
            menuShareVia.setGravity(menuTextGravity);
            menuShareViaTv.setText(stringResShareVia);
            menuShareViaTv.setTextSize(TypedValue.COMPLEX_UNIT_PX, menuTextSize);
            menuShareViaTv.setTypeface(TypefaceHelper.get(this, menuTextFont));
            menuShareViaTv.setTextColor(menuTextColor);
            menuShareViaTv.setPadding((int) menuTextPaddingLeft, 0, (int) menuTextPaddingRight, 0);

            menuCopyLink.setVisibility(showMenuCopyLink ? View.VISIBLE : View.GONE);
            menuCopyLink.setBackgroundResource(menuSelector);
            menuCopyLink.setGravity(menuTextGravity);
            menuCopyLinkTv.setText(stringResCopyLink);
            menuCopyLinkTv.setTextSize(TypedValue.COMPLEX_UNIT_PX, menuTextSize);
            menuCopyLinkTv.setTypeface(TypefaceHelper.get(this, menuTextFont));
            menuCopyLinkTv.setTextColor(menuTextColor);
            menuCopyLinkTv.setPadding((int) menuTextPaddingLeft, 0, (int) menuTextPaddingRight, 0);

            menuOpenWith.setVisibility(showMenuOpenWith ? View.VISIBLE : View.GONE);
            menuOpenWith.setBackgroundResource(menuSelector);
            menuOpenWith.setGravity(menuTextGravity);
            menuOpenWithTv.setText(stringResOpenWith);
            menuOpenWithTv.setTextSize(TypedValue.COMPLEX_UNIT_PX, menuTextSize);
            menuOpenWithTv.setTypeface(TypefaceHelper.get(this, menuTextFont));
            menuOpenWithTv.setTextColor(menuTextColor);
            menuOpenWithTv.setPadding((int) menuTextPaddingLeft, 0, (int) menuTextPaddingRight, 0);
        }
    }

    protected int getMaxWidth() {
        if (forward.getVisibility() == View.VISIBLE) {
            return DisplayUtil.getWidth() - UnitConverter.dpToPx(100);
        } else {
            return DisplayUtil.getWidth() - UnitConverter.dpToPx(52);
        }
    }

    protected void updateIcon(ImageButton icon, @DrawableRes int drawableRes) {

        int[][] states = new int[][]{
                new int[]{-android.R.attr.state_enabled}, // disabled
                new int[]{android.R.attr.state_pressed}, // pressed
                new int[]{}  // default
        };

        int[] colors = new int[]{
                iconDisabledColor,
                iconPressedColor,
                iconDefaultColor
        };

        ColorStateList colorStateList = new ColorStateList(states, colors);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            VectorDrawable drawable = (VectorDrawable) ContextCompat.getDrawable(this, drawableRes);
            drawable.setTintList(colorStateList);
            icon.setImageDrawable(drawable);

        } else {
            BitmapDrawable drawable = (BitmapDrawable) ContextCompat.getDrawable(this, drawableRes);
            //drawable.setTintList(colorStateList);
            icon.setImageDrawable(drawable);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        session = LanternApp.getSession();

        getOptions();
        if (theme != 0) setTheme(theme);
        setContentView(R.layout.finest_web_view);
        bindViews();
        layoutViews();
        initializeViews();
    }

    @Override
    public void onBackPressed() {
        if (menuLayout.getVisibility() == View.VISIBLE) {
            hideMenu();
        } else if (backPressToClose || !webView.canGoBack()) {
            close();
        } else {
            webView.goBack();
        }
    }

    public void onClick(View view) {
        int viewId = view.getId();
        if (viewId == R.id.close) {
            if (rtl) showMenu();
            else close();
        } else if (viewId == R.id.back) {
            if (rtl) webView.goForward();
            else webView.goBack();
        } else if (viewId == R.id.forward) {
            if (rtl) webView.goBack();
            else webView.goForward();
        } else if (viewId == R.id.more) {
            if (rtl) close();
            else showMenu();
        } else if (viewId == R.id.menuLayout) {
            hideMenu();
        } else if (viewId == R.id.menuRefresh) {
            webView.reload();
            hideMenu();
        } else if (viewId == R.id.menuFind) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB)
                webView.showFindDialog("", true);
            hideMenu();
        } else if (viewId == R.id.menuShareVia) {
            Intent sendIntent = new Intent();
            sendIntent.setAction(Intent.ACTION_SEND);
            sendIntent.putExtra(Intent.EXTRA_TEXT, webView.getUrl());
            sendIntent.setType("text/plain");
            startActivity(Intent.createChooser(sendIntent, getResources().getString(stringResShareVia)));

            hideMenu();
        } else if (viewId == R.id.menuCopyLink) {
            ClipboardManagerUtil.setText(webView.getUrl());

            Snackbar snackbar = Snackbar.make(coordinatorLayout, getString(stringResCopiedToClipboard), Snackbar.LENGTH_LONG);
            View snackbarView = snackbar.getView();
            snackbarView.setBackgroundColor(toolbarColor);
            if (snackbarView instanceof ViewGroup)
                updateChildTextView((ViewGroup) snackbarView);
            snackbar.show();

            hideMenu();
        } else if (viewId == R.id.menuOpenWith) {
            Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(webView.getUrl()));
            startActivity(browserIntent);

            hideMenu();
        }
    }

    protected void updateChildTextView(ViewGroup viewGroup) {
        if (viewGroup == null || viewGroup.getChildCount() == 0)
            return;

        for (int i = 0; i < viewGroup.getChildCount(); i++) {
            View view = viewGroup.getChildAt(i);
            if (view instanceof TextView) {
                TextView textView = (TextView) view;
                textView.setTextColor(titleColor);
                textView.setTypeface(TypefaceHelper.get(this, titleFont));
                textView.setLineSpacing(0, 1.1f);
                textView.setIncludeFontPadding(false);
            }

            if (view instanceof ViewGroup)
                updateChildTextView((ViewGroup) view);
        }
    }

    protected void showMenu() {
        menuLayout.setVisibility(View.VISIBLE);
        Animation popupAnim = AnimationUtils.loadAnimation(this, R.anim.popup_flyout_show);
        shadowLayout.startAnimation(popupAnim);
    }

    protected void hideMenu() {
        Animation popupAnim = AnimationUtils.loadAnimation(this, R.anim.popup_flyout_hide);
        shadowLayout.startAnimation(popupAnim);
        popupAnim.setAnimationListener(new Animation.AnimationListener() {
            @Override
            public void onAnimationStart(Animation animation) {
            }

            @Override
            public void onAnimationEnd(Animation animation) {
                menuLayout.setVisibility(View.GONE);
            }

            @Override
            public void onAnimationRepeat(Animation animation) {
            }
        });
    }

    protected void close() {
        super.onBackPressed();
        overridePendingTransition(animationCloseEnter, animationCloseExit);
    }

    @Override
    public void onOffsetChanged(AppBarLayout appBarLayout, int verticalOffset) {
        if (toolbarScrollFlags == 0)
            return;

        ViewHelper.setTranslationY(gradient, verticalOffset);
        ViewHelper.setAlpha(gradient, 1 - (float) Math.abs(verticalOffset) / (float) appBarLayout.getTotalScrollRange());

        switch (progressBarPosition) {
            case BOTTON_OF_TOOLBAR:
                ViewHelper.setTranslationY(progressBar, Math.max(verticalOffset, progressBarHeight - appBarLayout.getTotalScrollRange()));
                break;
            case TOP_OF_WEBVIEW:
                ViewHelper.setTranslationY(progressBar, verticalOffset);
                break;
            case TOP_OF_TOOLBAR:
            case BOTTOM_OF_WEBVIEW:
            default:
                break;
        }

        if (menuLayout.getVisibility() == View.VISIBLE
                && Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB)
            ViewHelper.setTranslationY(menuLayout, Math.max(verticalOffset, -getResources().getDimension(R.dimen.defaultMenuLayoutMargin)));
    }

    public class MyWebChromeClient extends WebChromeClient {

        @Override
        public void onProgressChanged(WebView view, int progress) {
            BroadCastManager.onProgressChanged(FinestWebViewActivity.this, key, progress);

            if (showSwipeRefreshLayout) {
                if (swipeRefreshLayout.isRefreshing() && progress == 100) {
                    swipeRefreshLayout.post(new Runnable() {
                        @Override
                        public void run() {
                            swipeRefreshLayout.setRefreshing(false);
                        }
                    });
                }

                if (!swipeRefreshLayout.isRefreshing() && progress != 100) {
                    swipeRefreshLayout.post(new Runnable() {
                        @Override
                        public void run() {
                            swipeRefreshLayout.setRefreshing(true);
                        }
                    });
                }
            }

            if (progress == 100)
                progress = 0;
            progressBar.setProgress(progress);
        }

        @Override
        public void onReceivedTitle(WebView view, String title) {
            BroadCastManager.onReceivedTitle(FinestWebViewActivity.this, key, title);
        }

        @Override
        public void onReceivedTouchIconUrl(WebView view, String url, boolean precomposed) {
            BroadCastManager.onReceivedTouchIconUrl(FinestWebViewActivity.this, key, url, precomposed);
        }
    }


    @Override
    public void onResult(boolean success) {
        if (!success) {
            Utils.showAlertDialog(FinestWebViewActivity.this, 
                    getResources().getString(R.string.app_name),
                    getResources().getString(R.string.invalid_payment_method), true);
            return;
        }

        session.linkDevice();
        session.setIsProUser(true);
        finish();
        startActivity(new Intent(FinestWebViewActivity.this, WelcomeActivity_.class));
    }              

    public class MyWebViewClient extends WebViewClient {

        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            BroadCastManager.onPageStarted(FinestWebViewActivity.this, key, url);
            if (!url.contains("docs.google.com") && url.endsWith(".pdf")) {
                webView.loadUrl("http://docs.google.com/gview?embedded=true&url=" + url);
            }
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            BroadCastManager.onPageFinished(FinestWebViewActivity.this, key, url);

            if (updateTitleFromHtml)
                title.setText(view.getTitle());
            urlTv.setText(UrlParser.getHost(url));
            requestCenterLayout();

            if (view.canGoBack() || view.canGoForward()) {
                back.setVisibility(showIconBack ? View.VISIBLE : View.GONE);
                forward.setVisibility(showIconForward ? View.VISIBLE : View.GONE);
                back.setEnabled(!disableIconBack && (rtl ? view.canGoForward() : view.canGoBack()));
                forward.setEnabled(!disableIconForward && (rtl ? view.canGoBack() : view.canGoForward()));
            } else {
                back.setVisibility(View.GONE);
                forward.setVisibility(View.GONE);
            }

            if (injectJavaScript != null)
                webView.loadUrl(injectJavaScript);
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            if (url.startsWith("lantern")) {
                Log.d(TAG, "Got a url that starts with lantern.. " + url);
                UrlQuerySanitizer sanitizer = new UrlQuerySanitizer(url);
                String stripeToken = sanitizer.getValue("stripeToken");
                String email = sanitizer.getValue("stripeEmail");
                if (stripeToken != null && email != null) { 
                    Log.d(TAG, "Got stripe token and email!!! " + stripeToken + " " + email);
                    finishProgress(email, stripeToken);
                }
                return true;
            } else if (url.endsWith(".mp4")) {
                Intent intent = new Intent(Intent.ACTION_VIEW);
                intent.setDataAndType(Uri.parse(url), "video/*");
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                view.getContext().startActivity(intent);
                // If we return true, onPageStarted, onPageFinished won't be called.
                return true;
            } else if (url.startsWith("tel:") || url.startsWith("sms:") || url.startsWith("smsto:") || url.startsWith("mms:") || url.startsWith("mmsto:")) {
                Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                view.getContext().startActivity(intent);
                return true; // If we return true, onPageStarted, onPageFinished won't be called.
            } else {
                return super.shouldOverrideUrlLoading(view, url);
            }
        }

        private void finishProgress(String email, String token) {

            String currency = session.getSelectedPlanCurrency();

            Log.d(TAG, String.format("Email is %s token %s plan %s user id %s token %s plan %s currency %s device id %s", 
                        email, token, session.Plan(), session.UserId(), session.Token(), session.getPlan(), currency, session.DeviceId()));

            session.setProUser(email, token);

            // submit token to Pro server here
            new ProRequest(FinestWebViewActivity.this, false, 
                FinestWebViewActivity.this).execute("purchase");
        }

        @Override
        public void onLoadResource(WebView view, String url) {
            BroadCastManager.onLoadResource(FinestWebViewActivity.this, key, url);
        }

        @Override
        public void onPageCommitVisible(WebView view, String url) {
            BroadCastManager.onPageCommitVisible(FinestWebViewActivity.this, key, url);
        }
    }

    DownloadListener downloadListener = new DownloadListener() {
        @Override
        public void onDownloadStart(String url, String userAgent, String contentDisposition, String mimetype, long contentLength) {
            BroadCastManager.onDownloadStart(FinestWebViewActivity.this, key, url, userAgent, contentDisposition, mimetype, contentLength);
        }
    };

    protected void requestCenterLayout() {
        int maxWidth;
        if (webView.canGoBack() || webView.canGoForward()) {
            maxWidth = DisplayUtil.getWidth() - UnitConverter.dpToPx(48) * 4;
        } else {
            maxWidth = DisplayUtil.getWidth() - UnitConverter.dpToPx(48) * 2;
        }

        title.setMaxWidth(maxWidth);
        urlTv.setMaxWidth(maxWidth);
        title.requestLayout();
        urlTv.requestLayout();
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);

        if (newConfig.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            layoutViews();
        } else if (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT) {
            layoutViews();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        BroadCastManager.unregister(FinestWebViewActivity.this, key);
        if (webView == null) return;
        if (APILevel.require(11)) webView.onPause();
    }

    // Wait for zoom control to fade away
    // https://code.google.com/p/android/issues/detail?id=15694
    // http://stackoverflow.com/a/5966151/1797648
    private void destroyWebView() {
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (webView != null) webView.destroy();
            }
        }, ViewConfiguration.getZoomControlsTimeout() + 1000L);
    }
}
