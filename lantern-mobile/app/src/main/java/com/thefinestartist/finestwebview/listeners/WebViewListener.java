package com.thefinestartist.finestwebview.listeners;

/**
 * Created by TheFinestArtist on 1/26/16.
 */
public abstract class WebViewListener {

    public void onProgressChanged(int progress) {}
    public void onReceivedTitle(String title) {}
    public void onReceivedTouchIconUrl(String url, boolean precomposed) {}

    public void onPageStarted(String url) {}
    public void onPageFinished(String url) {}
    public void onLoadResource(String url) {}
    public void onPageCommitVisible(String url) {}

    public void onDownloadStart(String url, String userAgent, String contentDisposition, String mimeType, long contentLength) {}
}
