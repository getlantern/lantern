package org.getlantern.lantern.model;

import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.view.ViewPager;
import android.util.Log;

import com.ogaclejapan.smarttablayout.utils.v4.FragmentPagerItemAdapter;
import com.ogaclejapan.smarttablayout.utils.v4.FragmentPagerItems;
import com.ogaclejapan.smarttablayout.SmartTabLayout;

import org.getlantern.lantern.activity.LanternMainActivity;
import org.getlantern.lantern.fragment.FeedFragment;
import org.getlantern.lantern.R;

import go.lantern.Lantern;

public class GetFeed extends AsyncTask<String, Void, Void> {
    private static final String TAG = "GetFeed";

    private LanternMainActivity activity;

    public GetFeed(LanternMainActivity activity) {
        this.activity = activity;
    }

    @Override
    protected Void doInBackground(String... params) {
        try {
            final FragmentPagerItems.Creator c = FragmentPagerItems.with(activity);
            Lantern.PullFeed(new Lantern.FeedProvider.Stub() {

                public void Finish() {
                    activity.runOnUiThread(new Runnable() {
                        public void run() {
                            FragmentPagerItemAdapter adapter = new FragmentPagerItemAdapter(
                                    activity.getSupportFragmentManager(), c.create());

                            ViewPager viewPager = (ViewPager) activity.findViewById(R.id.viewpager);
                            viewPager.setAdapter(adapter);

                            SmartTabLayout viewPagerTab = (SmartTabLayout)activity.findViewById(R.id.viewpagertab);
                            viewPagerTab.setViewPager(viewPager);
                        }
                    });
                }

                public void AddSource(String source) {
                    Bundle bundle = new Bundle();
                    bundle.putString("name", source);
                    c.add(source, FeedFragment.class, bundle);
                }
            });

        } catch (Exception e) {
            Log.v("Error Parsing Data", e + "");
        }
        return null;
    }

    @Override
    protected void onPostExecute(Void aVoid) {
        super.onPostExecute(aVoid);
    }
}   

