package org.lantern.model;

import android.app.Activity;
import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;
import android.view.View;
import android.widget.ProgressBar;

import org.lantern.activity.LanternMainActivity;
import org.lantern.R;

import java.util.ArrayList; 
import java.util.Locale;

import org.greenrobot.eventbus.EventBus;

import go.lantern.Lantern;

public class GetFeed extends AsyncTask<Boolean, Void, ArrayList<String>> {
    private static final String TAG = "GetFeed";

    private Context context;
    private LanternMainActivity activity;
    private String allString;
    private ProgressBar progressBar;

    public GetFeed(Context context) {
        this.context = context;
        this.allString = context.getResources().getString(R.string.all_feeds);
    }

    @Override
    protected ArrayList<String> doInBackground(Boolean... params) {

        boolean shouldProxy = params[0];
        String locale = Locale.getDefault().toString();
        Log.d(TAG, String.format("Fetching public feed: locale=%s", locale));
        final ArrayList<String> sources = new ArrayList<String>();

        Lantern.GetFeed(locale, allString, shouldProxy, new Lantern.FeedProvider() {
            public void AddSource(String source) {
                sources.add(source);
            }
        });
        return sources;
    }

    @Override
    protected void onPostExecute(ArrayList<String> sources) {
        super.onPostExecute(sources);

        if (progressBar != null) {
            progressBar.setVisibility(View.GONE);
        }
        EventBus.getDefault().post(sources);
    }
}   

