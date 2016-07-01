package com.thefinestartist.finestwebview;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.support.annotation.AnimRes;
import android.support.annotation.ArrayRes;
import android.support.annotation.ColorInt;
import android.support.annotation.ColorRes;
import android.support.annotation.DimenRes;
import android.support.annotation.DrawableRes;
import android.support.annotation.NonNull;
import android.support.annotation.StringRes;
import android.support.annotation.StyleRes;
import android.support.design.widget.AppBarLayout.LayoutParams.ScrollFlags;
import android.webkit.WebSettings;
import android.webkit.WebViewClient;

import com.thefinestartist.Base;
import com.thefinestartist.finestwebview.enums.Position;
import com.thefinestartist.finestwebview.listeners.BroadCastManager;
import com.thefinestartist.finestwebview.listeners.WebViewListener;
import com.thefinestartist.utils.content.Ctx;
import com.thefinestartist.utils.content.Res;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

import org.lantern.R;                           


/**
 * Created by Leonardo on 11/21/15.
 */
public class FinestWebView {

    public static class Builder implements Serializable {

        protected final transient Context context;
        protected transient List<WebViewListener> listeners = new ArrayList<>();

        protected Integer key;

        protected Boolean rtl;
        protected Integer theme;

        protected Integer statusBarColor;

        protected Integer toolbarColor;
        protected Integer toolbarScrollFlags;

        protected Integer iconDefaultColor;
        protected Integer iconDisabledColor;
        protected Integer iconPressedColor;
        protected Integer iconSelector;

        protected Boolean showIconClose;
        protected Boolean disableIconClose;
        protected Boolean showIconBack;
        protected Boolean disableIconBack;
        protected Boolean showIconForward;
        protected Boolean disableIconForward;
        protected Boolean showIconMenu;
        protected Boolean disableIconMenu;

        protected Boolean showSwipeRefreshLayout;
        protected Integer swipeRefreshColor;
        protected Integer[] swipeRefreshColors;

        protected Boolean showDivider;
        protected Boolean gradientDivider;
        protected Integer dividerColor;
        protected Float dividerHeight;

        protected Boolean showProgressBar;
        protected Integer progressBarColor;
        protected Float progressBarHeight;
        protected Position progressBarPosition;

        protected String titleDefault;
        protected Boolean updateTitleFromHtml;
        protected Float titleSize;
        protected String titleFont;
        protected Integer titleColor;

        protected Boolean showUrl;
        protected Float urlSize;
        protected String urlFont;
        protected Integer urlColor;

        protected Integer menuColor;
        protected Integer menuDropShadowColor;
        protected Float menuDropShadowSize;
        protected Integer menuSelector;

        protected Float menuTextSize;
        protected String menuTextFont;
        protected Integer menuTextColor;

        protected Integer menuTextGravity;
        protected Float menuTextPaddingLeft;
        protected Float menuTextPaddingRight;

        protected Boolean showMenuRefresh;
        protected Integer stringResRefresh;
        protected Boolean showMenuFind;
        protected Integer stringResFind;
        protected Boolean showMenuShareVia;
        protected Integer stringResShareVia;
        protected Boolean showMenuCopyLink;
        protected Integer stringResCopyLink;
        protected Boolean showMenuOpenWith;
        protected Integer stringResOpenWith;

        protected Integer animationOpenEnter = R.anim.modal_activity_open_enter;
        protected Integer animationOpenExit = R.anim.modal_activity_open_exit;
        protected Integer animationCloseEnter;
        protected Integer animationCloseExit;

        protected Boolean backPressToClose;
        protected Integer stringResCopiedToClipboard;

        protected Boolean webViewSupportZoom;
        protected Boolean webViewMediaPlaybackRequiresUserGesture;
        protected Boolean webViewBuiltInZoomControls;
        protected Boolean webViewDisplayZoomControls;
        protected Boolean webViewAllowFileAccess;
        protected String webViewProxyAddr;
        protected Boolean webViewInsideScrollStyle;
        protected WebViewClient webViewClient;
        protected Boolean webViewAllowContentAccess;
        protected Boolean webViewLoadWithOverviewMode;
        protected Boolean webViewSaveFormData;
        protected Integer webViewTextZoom;
        protected Boolean webViewUseWideViewPort;
        protected Boolean webViewSupportMultipleWindows;
        protected WebSettings.LayoutAlgorithm webViewLayoutAlgorithm;
        protected String webViewStandardFontFamily;
        protected String webViewFixedFontFamily;
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

        public Builder setWebViewListener(WebViewListener listener) {
            listeners.clear();
            listeners.add(listener);
            return this;
        }

        public Builder addWebViewListener(WebViewListener listener) {
            listeners.add(listener);
            return this;
        }

        public Builder removeWebViewListener(WebViewListener listener) {
            listeners.remove(listener);
            return this;
        }

        public Builder rtl(boolean rtl) {
            this.rtl = rtl;
            return this;
        }

        public Builder(@NonNull Activity activity) {
            this.context = activity;
            Base.initialize(activity);
        }

        /**
         * If you use context instead of activity, FinestWebView won't be able to override activity animation.
         * Try to create builder with Activity if it's possible.
         */
        public Builder(@NonNull Context context) {
            this.context = context;
            Base.initialize(context);
        }

        public Builder theme(@StyleRes int theme) {
            this.theme = theme;
            return this;
        }

        public Builder statusBarColor(@ColorInt int color) {
            this.statusBarColor = color;
            return this;
        }

        public Builder statusBarColorRes(@ColorRes int colorRes) {
            this.statusBarColor = Res.getColor(colorRes);
            return this;
        }

        public Builder toolbarColor(@ColorInt int color) {
            this.toolbarColor = color;
            return this;
        }

        public Builder toolbarColorRes(@ColorRes int colorRes) {
            this.toolbarColor = Res.getColor(colorRes);
            return this;
        }

        public Builder toolbarScrollFlags(@ScrollFlags int flags) {
            this.toolbarScrollFlags = flags;
            return this;
        }

        public Builder iconDefaultColor(@ColorInt int color) {
            this.iconDefaultColor = color;
            return this;
        }

        public Builder iconDefaultColorRes(@ColorRes int color) {
            this.iconDefaultColor = Res.getColor(color);
            return this;
        }

        public Builder iconDisabledColor(@ColorInt int color) {
            this.iconDisabledColor = color;
            return this;
        }

        public Builder iconDisabledColorRes(@ColorRes int colorRes) {
            this.iconDisabledColor = Res.getColor(colorRes);
            return this;
        }

        public Builder iconPressedColor(@ColorInt int color) {
            this.iconPressedColor = color;
            return this;
        }

        public Builder iconPressedColorRes(@ColorRes int colorRes) {
            this.iconPressedColor = Res.getColor(colorRes);
            return this;
        }

        public Builder iconSelector(@DrawableRes int selectorRes) {
            this.iconSelector = selectorRes;
            return this;
        }

        public Builder showIconClose(boolean showIconClose) {
            this.showIconClose = showIconClose;
            return this;
        }

        public Builder disableIconClose(boolean disableIconClose) {
            this.disableIconClose = disableIconClose;
            return this;
        }

        public Builder showIconBack(boolean showIconBack) {
            this.showIconBack = showIconBack;
            return this;
        }

        public Builder disableIconBack(boolean disableIconBack) {
            this.disableIconBack = disableIconBack;
            return this;
        }

        public Builder showIconForward(boolean showIconForward) {
            this.showIconForward = showIconForward;
            return this;
        }

        public Builder disableIconForward(boolean disableIconForward) {
            this.disableIconForward = disableIconForward;
            return this;
        }

        public Builder showIconMenu(boolean showIconMenu) {
            this.showIconMenu = showIconMenu;
            return this;
        }

        public Builder disableIconMenu(boolean disableIconMenu) {
            this.disableIconMenu = disableIconMenu;
            return this;
        }

        public Builder showSwipeRefreshLayout(boolean showSwipeRefreshLayout) {
            this.showSwipeRefreshLayout = showSwipeRefreshLayout;
            return this;
        }

        public Builder swipeRefreshColor(@ColorInt int color) {
            this.swipeRefreshColor = color;
            return this;
        }

        public Builder swipeRefreshColorRes(@ColorRes int colorRes) {
            this.swipeRefreshColor = Res.getColor(colorRes);
            return this;
        }

        public Builder swipeRefreshColors(int[] colors) {
            Integer[] swipeRefreshColors = new Integer[colors.length];
            for (int i = 0; i < colors.length; i++)
                swipeRefreshColors[i] = colors[i];
            this.swipeRefreshColors = swipeRefreshColors;
            return this;
        }

        public Builder swipeRefreshColorsRes(@ArrayRes int colorsRes) {
            int[] colors = Res.getIntArray(colorsRes);
            return swipeRefreshColors(colors);
        }

        public Builder showDivider(boolean showDivider) {
            this.showDivider = showDivider;
            return this;
        }

        public Builder gradientDivider(boolean gradientDivider) {
            this.gradientDivider = gradientDivider;
            return this;
        }

        public Builder dividerColor(@ColorInt int color) {
            this.dividerColor = color;
            return this;
        }

        public Builder dividerColorRes(@ColorRes int colorRes) {
            this.dividerColor = Res.getColor(colorRes);
            return this;
        }

        public Builder dividerHeight(float height) {
            this.dividerHeight = height;
            return this;
        }

        public Builder dividerHeight(int height) {
            this.dividerHeight = (float) height;
            return this;
        }

        public Builder dividerHeightRes(@DimenRes int height) {
            this.dividerHeight = Res.getDimension(height);
            return this;
        }

        public Builder showProgressBar(boolean showProgressBar) {
            this.showProgressBar = showProgressBar;
            return this;
        }

        public Builder progressBarColor(@ColorInt int color) {
            this.progressBarColor = color;
            return this;
        }

        public Builder progressBarColorRes(@ColorRes int colorRes) {
            this.progressBarColor = Res.getColor(colorRes);
            return this;
        }

        public Builder progressBarHeight(float height) {
            this.progressBarHeight = height;
            return this;
        }

        public Builder progressBarHeight(int height) {
            this.progressBarHeight = (float) height;
            return this;
        }

        public Builder progressBarHeightRes(@DimenRes int height) {
            this.progressBarHeight = Res.getDimension(height);
            return this;
        }

        public Builder progressBarPosition(@NonNull Position position) {
            this.progressBarPosition = position;
            return this;
        }

        public Builder titleDefault(@NonNull String title) {
            this.titleDefault = title;
            return this;
        }

        public Builder titleDefaultRes(@StringRes int stringRes) {
            this.titleDefault = Res.getString(stringRes);
            return this;
        }

        public Builder updateTitleFromHtml(boolean updateTitleFromHtml) {
            this.updateTitleFromHtml = updateTitleFromHtml;
            return this;
        }

        public Builder titleSize(float titleSize) {
            this.titleSize = titleSize;
            return this;
        }

        public Builder titleSize(int titleSize) {
            this.titleSize = (float) titleSize;
            return this;
        }

        public Builder titleSizeRes(@DimenRes int titleSize) {
            this.titleSize = Res.getDimension(titleSize);
            return this;
        }

        public Builder titleFont(String titleFont) {
            this.titleFont = titleFont;
            return this;
        }

        public Builder titleColor(@ColorInt int color) {
            this.titleColor = color;
            return this;
        }

        public Builder titleColorRes(@ColorRes int colorRes) {
            this.titleColor = Res.getColor(colorRes);
            return this;
        }

        public Builder showUrl(boolean showUrl) {
            this.showUrl = showUrl;
            return this;
        }

        public Builder urlSize(float urlSize) {
            this.urlSize = urlSize;
            return this;
        }

        public Builder urlSize(int urlSize) {
            this.urlSize = (float) urlSize;
            return this;
        }

        public Builder urlSizeRes(@DimenRes int urlSize) {
            this.urlSize = Res.getDimension(urlSize);
            return this;
        }

        public Builder urlFont(String urlFont) {
            this.urlFont = urlFont;
            return this;
        }

        public Builder urlColor(@ColorInt int color) {
            this.urlColor = color;
            return this;
        }

        public Builder urlColorRes(@ColorRes int colorRes) {
            this.urlColor = Res.getColor(colorRes);
            return this;
        }

        public Builder menuColor(@ColorInt int color) {
            this.menuColor = color;
            return this;
        }

        public Builder menuColorRes(@ColorRes int colorRes) {
            this.menuColor = Res.getColor(colorRes);
            return this;
        }

        public Builder menuTextGravity(int gravity) {
            this.menuTextGravity = gravity;
            return this;
        }

        public Builder menuTextPaddingLeft(float menuTextPaddingLeft) {
            this.menuTextPaddingLeft = menuTextPaddingLeft;
            return this;
        }

        public Builder menuTextPaddingLeft(int menuTextPaddingLeft) {
            this.menuTextPaddingLeft = (float) menuTextPaddingLeft;
            return this;
        }

        public Builder menuTextPaddingLeftRes(@DimenRes int menuTextPaddingLeft) {
            this.menuTextPaddingLeft = Res.getDimension(menuTextPaddingLeft);
            return this;
        }

        public Builder menuTextPaddingRight(float menuTextPaddingRight) {
            this.menuTextPaddingRight = menuTextPaddingRight;
            return this;
        }

        public Builder menuTextPaddingRight(int menuTextPaddingRight) {
            this.menuTextPaddingRight = (float) menuTextPaddingRight;
            return this;
        }

        public Builder menuTextPaddingRightRes(@DimenRes int menuTextPaddingRight) {
            this.menuTextPaddingRight = Res.getDimension(menuTextPaddingRight);
            return this;
        }

        public Builder menuDropShadowColor(@ColorInt int color) {
            this.menuDropShadowColor = color;
            return this;
        }

        public Builder menuDropShadowColorRes(@ColorRes int colorRes) {
            this.menuDropShadowColor = Res.getColor(colorRes);
            return this;
        }

        public Builder menuDropShadowSize(float menuDropShadowSize) {
            this.menuDropShadowSize = menuDropShadowSize;
            return this;
        }

        public Builder menuDropShadowSize(int menuDropShadowSize) {
            this.menuDropShadowSize = (float) menuDropShadowSize;
            return this;
        }

        public Builder menuDropShadowSizeRes(@DimenRes int menuDropShadowSize) {
            this.menuDropShadowSize = Res.getDimension(menuDropShadowSize);
            return this;
        }

        public Builder menuSelector(@DrawableRes int selectorRes) {
            this.menuSelector = selectorRes;
            return this;
        }

        public Builder menuTextSize(float menuTextSize) {
            this.menuTextSize = menuTextSize;
            return this;
        }

        public Builder menuTextSize(int menuTextSize) {
            this.menuTextSize = (float) menuTextSize;
            return this;
        }

        public Builder menuTextSizeRes(@DimenRes int menuTextSize) {
            this.menuTextSize = Res.getDimension(menuTextSize);
            return this;
        }

        public Builder menuTextFont(String menuTextFont) {
            this.menuTextFont = menuTextFont;
            return this;
        }

        public Builder menuTextColor(@ColorInt int color) {
            this.menuTextColor = color;
            return this;
        }

        public Builder menuTextColorRes(@ColorRes int colorRes) {
            this.menuTextColor = Res.getColor(colorRes);
            return this;
        }

        public Builder showMenuRefresh(boolean showMenuRefresh) {
            this.showMenuRefresh = showMenuRefresh;
            return this;
        }

        public Builder stringResRefresh(@StringRes int stringResRefresh) {
            this.stringResRefresh = stringResRefresh;
            return this;
        }

        public Builder showMenuFind(boolean showMenuFind) {
            this.showMenuFind = showMenuFind;
            return this;
        }

        public Builder stringResFind(@StringRes int stringResFind) {
            this.stringResFind = stringResFind;
            return this;
        }

        public Builder showMenuShareVia(boolean showMenuShareVia) {
            this.showMenuShareVia = showMenuShareVia;
            return this;
        }

        public Builder stringResShareVia(@StringRes int stringResShareVia) {
            this.stringResShareVia = stringResShareVia;
            return this;
        }

        public Builder showMenuCopyLink(boolean showMenuCopyLink) {
            this.showMenuCopyLink = showMenuCopyLink;
            return this;
        }

        public Builder stringResCopyLink(@StringRes int stringResCopyLink) {
            this.stringResCopyLink = stringResCopyLink;
            return this;
        }

        public Builder showMenuOpenWith(boolean showMenuOpenWith) {
            this.showMenuOpenWith = showMenuOpenWith;
            return this;
        }

        public Builder stringResOpenWith(@StringRes int stringResOpenWith) {
            this.stringResOpenWith = stringResOpenWith;
            return this;
        }

        public Builder setCustomAnimations(@AnimRes int animationOpenEnter,
                                           @AnimRes int animationOpenExit,
                                           @AnimRes int animationCloseEnter,
                                           @AnimRes int animationCloseExit) {
            this.animationOpenEnter = animationOpenEnter;
            this.animationOpenExit = animationOpenExit;
            this.animationCloseEnter = animationCloseEnter;
            this.animationCloseExit = animationCloseExit;
            return this;
        }

        /**
         * @deprecated As of release 1.0.1, replaced by {@link #setCustomAnimations(int, int, int, int)}
         */
        public Builder setCloseAnimations(@AnimRes int animationCloseEnter,
                                          @AnimRes int animationCloseExit) {
            this.animationCloseEnter = animationCloseEnter;
            this.animationCloseExit = animationCloseExit;
            return this;
        }

        public Builder backPressToClose(boolean backPressToClose) {
            this.backPressToClose = backPressToClose;
            return this;
        }

        public Builder stringResCopiedToClipboard(@StringRes int stringResCopiedToClipboard) {
            this.stringResCopiedToClipboard = stringResCopiedToClipboard;
            return this;
        }

        public Builder webViewSupportZoom(boolean webViewSupportZoom) {
            this.webViewSupportZoom = webViewSupportZoom;
            return this;
        }

        public Builder webViewMediaPlaybackRequiresUserGesture(boolean webViewMediaPlaybackRequiresUserGesture) {
            this.webViewMediaPlaybackRequiresUserGesture = webViewMediaPlaybackRequiresUserGesture;
            return this;
        }

        public Builder webViewBuiltInZoomControls(boolean webViewBuiltInZoomControls) {
            this.webViewBuiltInZoomControls = webViewBuiltInZoomControls;
            return this;
        }

        public Builder webViewDisplayZoomControls(boolean webViewDisplayZoomControls) {
            this.webViewDisplayZoomControls = webViewDisplayZoomControls;
            return this;
        }

        public Builder webViewAllowFileAccess(boolean webViewAllowFileAccess) {
            this.webViewAllowFileAccess = webViewAllowFileAccess;
            return this;
        }

        public Builder webViewLoadWithProxy(String webViewProxyAddr) {
            this.webViewProxyAddr = webViewProxyAddr;
            return this;
        }

        public Builder webViewInsideScrollStyle(boolean insideStyle) {
            this.webViewInsideScrollStyle = insideStyle;
            return this;
        }

        public Builder webViewWithClient(WebViewClient webViewClient) {
            this.webViewClient = webViewClient;
            return this;
        }

        public Builder webViewAllowContentAccess(boolean webViewAllowContentAccess) {
            this.webViewAllowContentAccess = webViewAllowContentAccess;
            return this;
        }

        public Builder webViewLoadWithOverviewMode(boolean webViewLoadWithOverviewMode) {
            this.webViewLoadWithOverviewMode = webViewLoadWithOverviewMode;
            return this;
        }

        public Builder webViewSaveFormData(boolean webViewSaveFormData) {
            this.webViewSaveFormData = webViewSaveFormData;
            return this;
        }

        public Builder webViewTextZoom(int webViewTextZoom) {
            this.webViewTextZoom = webViewTextZoom;
            return this;
        }

        public Builder webViewUseWideViewPort(boolean webViewUseWideViewPort) {
            this.webViewUseWideViewPort = webViewUseWideViewPort;
            return this;
        }

        public Builder webViewSupportMultipleWindows(boolean webViewSupportMultipleWindows) {
            this.webViewSupportMultipleWindows = webViewSupportMultipleWindows;
            return this;
        }

        public Builder webViewLayoutAlgorithm(WebSettings.LayoutAlgorithm webViewLayoutAlgorithm) {
            this.webViewLayoutAlgorithm = webViewLayoutAlgorithm;
            return this;
        }

        public Builder webViewStandardFontFamily(String webViewStandardFontFamily) {
            this.webViewStandardFontFamily = webViewStandardFontFamily;
            return this;
        }

        public Builder webViewFixedFontFamily(String webViewFixedFontFamily) {
            this.webViewFixedFontFamily = webViewFixedFontFamily;
            return this;
        }

        public Builder webViewSansSerifFontFamily(String webViewSansSerifFontFamily) {
            this.webViewSansSerifFontFamily = webViewSansSerifFontFamily;
            return this;
        }

        public Builder webViewSerifFontFamily(String webViewSerifFontFamily) {
            this.webViewSerifFontFamily = webViewSerifFontFamily;
            return this;
        }

        public Builder webViewCursiveFontFamily(String webViewCursiveFontFamily) {
            this.webViewCursiveFontFamily = webViewCursiveFontFamily;
            return this;
        }

        public Builder webViewFantasyFontFamily(String webViewFantasyFontFamily) {
            this.webViewFantasyFontFamily = webViewFantasyFontFamily;
            return this;
        }

        public Builder webViewMinimumFontSize(int webViewMinimumFontSize) {
            this.webViewMinimumFontSize = webViewMinimumFontSize;
            return this;
        }

        public Builder webViewMinimumLogicalFontSize(int webViewMinimumLogicalFontSize) {
            this.webViewMinimumLogicalFontSize = webViewMinimumLogicalFontSize;
            return this;
        }

        public Builder webViewDefaultFontSize(int webViewDefaultFontSize) {
            this.webViewDefaultFontSize = webViewDefaultFontSize;
            return this;
        }

        public Builder webViewDefaultFixedFontSize(int webViewDefaultFixedFontSize) {
            this.webViewDefaultFixedFontSize = webViewDefaultFixedFontSize;
            return this;
        }

        public Builder webViewLoadsImagesAutomatically(boolean webViewLoadsImagesAutomatically) {
            this.webViewLoadsImagesAutomatically = webViewLoadsImagesAutomatically;
            return this;
        }

        public Builder webViewBlockNetworkImage(boolean webViewBlockNetworkImage) {
            this.webViewBlockNetworkImage = webViewBlockNetworkImage;
            return this;
        }

        public Builder webViewBlockNetworkLoads(boolean webViewBlockNetworkLoads) {
            this.webViewBlockNetworkLoads = webViewBlockNetworkLoads;
            return this;
        }

        public Builder webViewJavaScriptEnabled(boolean webViewJavaScriptEnabled) {
            this.webViewJavaScriptEnabled = webViewJavaScriptEnabled;
            return this;
        }

        public Builder webViewAllowUniversalAccessFromFileURLs(boolean webViewAllowUniversalAccessFromFileURLs) {
            this.webViewAllowUniversalAccessFromFileURLs = webViewAllowUniversalAccessFromFileURLs;
            return this;
        }

        public Builder webViewAllowFileAccessFromFileURLs(boolean webViewAllowFileAccessFromFileURLs) {
            this.webViewAllowFileAccessFromFileURLs = webViewAllowFileAccessFromFileURLs;
            return this;
        }

        public Builder webViewGeolocationDatabasePath(String webViewGeolocationDatabasePath) {
            this.webViewGeolocationDatabasePath = webViewGeolocationDatabasePath;
            return this;
        }

        public Builder webViewAppCacheEnabled(boolean webViewAppCacheEnabled) {
            this.webViewAppCacheEnabled = webViewAppCacheEnabled;
            return this;
        }

        public Builder webViewAppCachePath(String webViewAppCachePath) {
            this.webViewAppCachePath = webViewAppCachePath;
            return this;
        }

        public Builder webViewDatabaseEnabled(boolean webViewDatabaseEnabled) {
            this.webViewDatabaseEnabled = webViewDatabaseEnabled;
            return this;
        }

        public Builder webViewDomStorageEnabled(boolean webViewDomStorageEnabled) {
            this.webViewDomStorageEnabled = webViewDomStorageEnabled;
            return this;
        }

        public Builder webViewGeolocationEnabled(boolean webViewGeolocationEnabled) {
            this.webViewGeolocationEnabled = webViewGeolocationEnabled;
            return this;
        }

        public Builder webViewJavaScriptCanOpenWindowsAutomatically(boolean webViewJavaScriptCanOpenWindowsAutomatically) {
            this.webViewJavaScriptCanOpenWindowsAutomatically = webViewJavaScriptCanOpenWindowsAutomatically;
            return this;
        }

        public Builder webViewDefaultTextEncodingName(String webViewDefaultTextEncodingName) {
            this.webViewDefaultTextEncodingName = webViewDefaultTextEncodingName;
            return this;
        }

        public Builder webViewUserAgentString(String webViewUserAgentString) {
            this.webViewUserAgentString = webViewUserAgentString;
            return this;
        }

        public Builder webViewNeedInitialFocus(boolean webViewNeedInitialFocus) {
            this.webViewNeedInitialFocus = webViewNeedInitialFocus;
            return this;
        }

        public Builder webViewCacheMode(int webViewCacheMode) {
            this.webViewCacheMode = webViewCacheMode;
            return this;
        }

        public Builder webViewMixedContentMode(int webViewMixedContentMode) {
            this.webViewMixedContentMode = webViewMixedContentMode;
            return this;
        }

        public Builder webViewOffscreenPreRaster(boolean webViewOffscreenPreRaster) {
            this.webViewOffscreenPreRaster = webViewOffscreenPreRaster;
            return this;
        }

        /**
         * @deprecated As of release 1.1.1, replaced by {@link #webViewUserAgentString(String)}
         * Use setUserAgentString("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.4) Gecko/20100101 Firefox/4.0") instead
         */
        public Builder webViewDesktopMode(boolean webViewDesktopMode) {
            return webViewUserAgentString("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.4) Gecko/20100101 Firefox/4.0");
        }

        public Builder injectJavaScript(String injectJavaScript) {
            this.injectJavaScript = injectJavaScript;
            return this;
        }

        public void load(@StringRes int dataRes) {
            load(Res.getString(dataRes));
        }

        public void load(String data) {
            load(data, "text/html", "UTF-8");
        }

        public void load(String data, String mimeType, String encoding) {
            this.mimeType = mimeType;
            this.encoding = encoding;
            show(null, data);
        }

        public void show(@StringRes int urlRes) {
            show(Res.getString(urlRes));
        }

        public void show(@NonNull String url) {
            show(url, null);
        }

        protected void show(String url, String data) {
            this.url = url;
            this.data = data;
            this.key = System.identityHashCode(this);

            if (!listeners.isEmpty()) new BroadCastManager(context, key, listeners);

            Intent intent = new Intent(context, FinestWebViewActivity.class);
            intent.putExtra("builder", this);

            Ctx.startActivity(intent);

            if (context instanceof Activity)
                ((Activity) context).overridePendingTransition(animationOpenEnter, animationOpenExit);
        }
    }
}
