package org.getlantern.lantern.fragment;

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
import java.util.Collections;
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

        Bundle bundle = getArguments();
        this.feedName = bundle.getString("name");
        this.mFeedItems = Collections.synchronizedList(new ArrayList<FeedItem>());
    }

    public String getFeedName() {
        return feedName;
    }

    public void NotifyDataSetChanged(final List<FeedItem> items) {
        getActivity().runOnUiThread(new Runnable() {
            public void run() {
                mFeedItems.clear();
                mFeedItems.addAll(items);
                Log.d(TAG, String.format("Feed %s has %d items", feedName, 
                            mFeedItems.size()));
                if (adapter != null) {
                    adapter.notifyDataSetChanged(); 
                }
            }
        });
    }   

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
            Bundle savedInstanceState) {

        View view = inflater.inflate(R.layout.feed_fragment, container, false);

        mList = (ListView)view.findViewById(R.id.feed);
        adapter = new FeedAdapter(getActivity(), mFeedItems);
        mList.setAdapter(adapter);
        return view;
    }

    @Override
    public void onViewCreated(View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        Log.d(TAG, "Created view for " + this.feedName);
        new Thread() {
            public void run() {
                final List<FeedItem> items = new ArrayList<FeedItem>();

                Lantern.FeedByName(feedName, new Lantern.FeedRetriever.Stub() {
                    public void AddFeed(String title, String desc, 
                            String image, String url) {
                        items.add(new FeedItem(title, desc, image, url));
                    }
                });

                NotifyDataSetChanged(items);
            }
        }.start();
    }
}
