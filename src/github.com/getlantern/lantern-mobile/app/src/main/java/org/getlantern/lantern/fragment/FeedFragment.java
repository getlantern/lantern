package org.getlantern.lantern.fragment;

import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ListView;


import org.getlantern.lantern.model.FeedAdapter;
import org.getlantern.lantern.model.FeedItem;
import org.getlantern.lantern.R;

import java.util.ArrayList;
import java.util.List;

import go.lantern.Lantern;

public class FeedFragment extends Fragment {

    private static final String TAG = "FeedFragment";

    private FeedAdapter adapter;
    private String feedName;
    private ListView mList;
    private List<FeedItem> mFeedItems;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.mFeedItems = new ArrayList<FeedItem>();
        this.adapter = new FeedAdapter(getActivity(), mFeedItems);

        Bundle bundle = getArguments();
        if (bundle != null) {
            this.feedName = bundle.getString("name");
        }
    }

    public String getFeedName() {
        return feedName;
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
            Bundle savedInstanceState) {

        View view = inflater.inflate(R.layout.feed_fragment, container, false);

        mList = (ListView)view.findViewById(R.id.feed);
        mList.setAdapter(adapter);
        return view;
    }

    private class LoadFeed extends AsyncTask<String, Void, List<FeedItem>> {

        @Override
        protected List<FeedItem> doInBackground(String... params) {

            String name = params[0];

            final List<FeedItem> items = new ArrayList<FeedItem>();

            Lantern.FeedByName(name, new Lantern.FeedRetriever() {
                public void AddFeed(String title, String desc,
                        String image, String url) {
                    items.add(new FeedItem(title, desc, image, url));
                }
            });

            return items;
        }

        @Override
        protected void onPostExecute(List<FeedItem> items) {
            super.onPostExecute(items);

            mFeedItems.clear();
            mFeedItems.addAll(items);

            if (feedName != null) {
                Log.d(TAG, String.format("Feed %s has %d items", feedName,
                            items.size()));
            }

            if (adapter != null) {
                // notify feed adapter underlying data has changed
                // and its time to refresh the view
                adapter.notifyDataSetChanged();
            }
        }
    }

    @Override
    public void onViewCreated(View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        if (this.feedName != null && !this.feedName.equals("")) {
            // only proceed if we have a valid feed name
            Log.d(TAG, "onViewCreated for " + this.feedName);
            new LoadFeed().execute(this.feedName);
        }
    }
}
