package org.getlantern.lantern.model;

import android.os.AsyncTask;
import android.util.Log;

import org.getlantern.lantern.activity.LanternMainActivity;

import java.util.ArrayList; 
import java.util.Collections;
import java.util.Locale;

import go.lantern.Lantern;

public class GetFeed extends AsyncTask<String, Void, ArrayList<String>> {
    private static final String TAG = "GetFeed";

    private LanternMainActivity activity;
    private String proxyAddr = "";

    public GetFeed(LanternMainActivity activity, String proxyAddr) {
        this.activity = activity;
        this.proxyAddr = proxyAddr;
    }

    @Override
    protected ArrayList<String> doInBackground(String... params) {
        String locale = Locale.getDefault().toString();
        Log.d(TAG, String.format("Fetching public feed: locale=%s; proxy addr=%s", locale, proxyAddr));
        final ArrayList<String> sources = new ArrayList<String>();

        Lantern.GetFeed(locale, proxyAddr, new Lantern.FeedProvider.Stub() {
            public void AddSource(String source) {
                sources.add(source);
            }
        });

        Collections.sort(sources, String.CASE_INSENSITIVE_ORDER);
        return sources;
    }

    @Override
    protected void onPostExecute(ArrayList<String> sources) {
        super.onPostExecute(sources);
        activity.setupFeed(sources);
    }
}   

