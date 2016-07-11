package com.thefinestartist.finestwebview.listeners;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.support.annotation.NonNull;
import android.support.v4.content.LocalBroadcastManager;

import java.util.List;

/**
 * Created by TheFinestArtist on 1/26/16.
 */
public class BroadCastManager {

    static final String WEBVIEW_EVENT = "WEBVIEW_EVENT";
    static final String EXTRA_KEY = "EXTRA_KEY";
    static final String EXTRA_TYPE = "EXTRA_TYPE";
    static final String EXTRA_URL = "EXTRA_URL";
    static final String EXTRA_TITLE = "EXTRA_TITLE";
    static final String EXTRA_PROGESS = "EXTRA_PROGESS";
    static final String EXTRA_PRECOMPOSED = "EXTRA_PRECOMPOSED";
    static final String EXTRA_USER_AGENT = "EXTRA_USER_AGENT";
    static final String EXTRA_CONTENT_DISPOSITION = "EXTRA_CONTENT_DISPOSITION";
    static final String EXTRA_MIME_TYPE = "EXTRA_MIME_TYPE";
    static final String EXTRA_CONTENT_LENGTH = "EXTRA_CONTENT_LENGTH";

    protected int key;
    protected List<WebViewListener> listeners;
    protected LocalBroadcastManager manager;
    protected BroadcastReceiver receiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (context == null || intent == null) return;
            int key = intent.getIntExtra(EXTRA_KEY, Integer.MIN_VALUE);
            if (BroadCastManager.this.key == key) handleIntent(intent);
        }
    };

    public BroadCastManager(Context context, int key, @NonNull List<WebViewListener> listeners) {
        this.key = key;
        this.listeners = listeners;
        manager = LocalBroadcastManager.getInstance(context);
        manager.registerReceiver(receiver, new IntentFilter(WEBVIEW_EVENT));
    }

    public enum Type {
        PROGRESS_CHANGED, RECEIVED_TITLE, RECEIVED_TOUCH_ICON_URL, PAGE_STARTED, PAGE_FINISHED, LOAD_RESOURCE, PAGE_COMMIT_VISIBLE, DOWNLOADED_START, UNREGISTER
    }

    private void handleIntent(@NonNull Intent intent) {
        Type type = (Type) intent.getSerializableExtra(EXTRA_TYPE);
        switch (type) {
            case PROGRESS_CHANGED:
                onProgressChanged(intent);
                break;
            case RECEIVED_TITLE:
                onReceivedTitle(intent);
                break;
            case RECEIVED_TOUCH_ICON_URL:
                onReceivedTouchIconUrl(intent);
                break;
            case PAGE_STARTED:
                onPageStarted(intent);
                break;
            case PAGE_FINISHED:
                onPageFinished(intent);
                break;
            case LOAD_RESOURCE:
                onLoadResource(intent);
                break;
            case PAGE_COMMIT_VISIBLE:
                onPageCommitVisible(intent);
                break;
            case UNREGISTER:
                unregister();
                break;
        }
    }

    // Base Static Methods
    private static Intent getBaseIntent(int key, Type type) {
        return new Intent(BroadCastManager.WEBVIEW_EVENT)
                .putExtra(EXTRA_KEY, key)
                .putExtra(EXTRA_TYPE, type);
    }

    private static void sendBroadCast(Context context, Intent intent) {
        LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
    }

    // Handle Each Event Type
    public static void onProgressChanged(Context context, int key, int progress) {
        Intent intent = getBaseIntent(key, Type.PROGRESS_CHANGED)
                .putExtra(EXTRA_PROGESS, progress);
        sendBroadCast(context, intent);
    }

    public void onProgressChanged(Intent intent) {
        for (WebViewListener listener : listeners)
            listener.onProgressChanged(
                    intent.getIntExtra(EXTRA_PROGESS, 0));
    }

    public static void onReceivedTitle(Context context, int key, String title) {
        Intent intent = getBaseIntent(key, Type.RECEIVED_TITLE)
                .putExtra(EXTRA_TITLE, title);
        sendBroadCast(context, intent);
    }

    public void onReceivedTitle(Intent intent) {
        for (WebViewListener listener : listeners)
            listener.onReceivedTitle(
                    intent.getStringExtra(EXTRA_TITLE));
    }

    public static void onReceivedTouchIconUrl(Context context, int key, String url, boolean precomposed) {
        Intent intent = getBaseIntent(key, Type.RECEIVED_TOUCH_ICON_URL)
                .putExtra(EXTRA_URL, url)
                .putExtra(EXTRA_PRECOMPOSED, precomposed);
        sendBroadCast(context, intent);
    }

    public void onReceivedTouchIconUrl(Intent intent) {
        for (WebViewListener listener : listeners)
            listener.onReceivedTouchIconUrl(
                    intent.getStringExtra(EXTRA_URL),
                    intent.getBooleanExtra(EXTRA_PRECOMPOSED, false));
    }

    public static void onPageStarted(Context context, int key, String url) {
        Intent intent = getBaseIntent(key, Type.PAGE_STARTED)
                .putExtra(EXTRA_URL, url);
        sendBroadCast(context, intent);
    }

    public void onPageStarted(Intent intent) {
        for (WebViewListener listener : listeners)
            listener.onPageStarted(
                    intent.getStringExtra(EXTRA_URL));
    }

    public static void onPageFinished(Context context, int key, String url) {
        Intent intent = getBaseIntent(key, Type.PAGE_FINISHED)
                .putExtra(EXTRA_URL, url);
        sendBroadCast(context, intent);
    }

    public void onPageFinished(Intent intent) {
        for (WebViewListener listener : listeners)
            listener.onPageFinished(
                    intent.getStringExtra(EXTRA_URL));
    }

    public static void onLoadResource(Context context, int key, String url) {
        Intent intent = getBaseIntent(key, Type.LOAD_RESOURCE)
                .putExtra(EXTRA_URL, url);
        sendBroadCast(context, intent);
    }

    public void onLoadResource(Intent intent) {
        for (WebViewListener listener : listeners)
            listener.onLoadResource(
                    intent.getStringExtra(EXTRA_URL));
    }

    public static void onPageCommitVisible(Context context, int key, String url) {
        Intent intent = getBaseIntent(key, Type.PAGE_COMMIT_VISIBLE)
                .putExtra(EXTRA_URL, url);
        sendBroadCast(context, intent);
    }

    public void onPageCommitVisible(Intent intent) {
        for (WebViewListener listener : listeners)
            listener.onPageCommitVisible(
                    intent.getStringExtra(EXTRA_URL));
    }

    public static void onDownloadStart(Context context, int key, String url, String userAgent, String contentDisposition, String mimeType, long contentLength) {
        Intent intent = getBaseIntent(key, Type.DOWNLOADED_START)
                .putExtra(EXTRA_URL, url)
                .putExtra(EXTRA_USER_AGENT, userAgent)
                .putExtra(EXTRA_CONTENT_DISPOSITION, contentDisposition)
                .putExtra(EXTRA_MIME_TYPE, mimeType)
                .putExtra(EXTRA_CONTENT_LENGTH, contentLength);
        sendBroadCast(context, intent);
    }

    public void onDownloadStart(Intent intent) {
        for (WebViewListener listener : listeners)
            listener.onDownloadStart(
                    intent.getStringExtra(EXTRA_URL),
                    intent.getStringExtra(EXTRA_USER_AGENT),
                    intent.getStringExtra(EXTRA_CONTENT_DISPOSITION),
                    intent.getStringExtra(EXTRA_MIME_TYPE),
                    intent.getLongExtra(EXTRA_CONTENT_LENGTH, 0l));
    }

    public static void unregister(Context context, int key) {
        Intent intent = getBaseIntent(key, Type.UNREGISTER);
        sendBroadCast(context, intent);
    }

    private void unregister() {
        if (manager != null && receiver != null)
            manager.unregisterReceiver(receiver);
    }
}
