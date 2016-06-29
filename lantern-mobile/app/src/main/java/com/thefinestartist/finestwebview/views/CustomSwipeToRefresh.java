package com.thefinestartist.finestwebview.views;

import android.content.Context;
import android.support.v4.widget.SwipeRefreshLayout;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;
import android.webkit.WebView;

import com.thefinestartist.converters.UnitConverter;

/**
 * Created by TheFinestArtist on 3/12/16.
 */
public class CustomSwipeToRefresh extends SwipeRefreshLayout {

    private static final int SCROLL_BUFFER_DIMEN = 1;
    private static int scrollBuffer;
    private WebView webView;

    public CustomSwipeToRefresh(Context context) {
        super(context);
    }

    public CustomSwipeToRefresh(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    private void initializeBuffer() {
        scrollBuffer = UnitConverter.dpToPx(SCROLL_BUFFER_DIMEN);
    }

    @Override
    public void addView(View child) {
        super.addView(child);
        if (child instanceof WebView)
            this.webView = (WebView) child;
    }

    @Override
    public boolean onInterceptTouchEvent(MotionEvent event) {
        return webView.getScrollY() <= scrollBuffer && super.onInterceptTouchEvent(event);
    }
}
