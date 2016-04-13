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

import go.lantern.Lantern;                    

public class FeedFragment extends Fragment {

    private static final String TAG = "FeedFragment";

    private FeedAdapter adapter;
    private String feedName;
    private ListView mList;
    private ArrayList<FeedItem> mFeedItems = new ArrayList<FeedItem>();


    public FeedFragment() {
        this.feedName = "";
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Bundle bundle = getArguments();
        this.feedName = bundle.getString("name");
    }

    public void NotifyDataSetChanged() {
        getActivity().runOnUiThread(new Runnable() {
            public void run() {
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
        Thread feedThread = new Thread() {
            public void run() {
                Lantern.FeedByName(feedName, new Lantern.FeedRetriever.Stub() {
                    public void AddFeed(String title, String desc, String image, String url) {
                        mFeedItems.add(new FeedItem(title, desc, image, url));
                    }
                    public void Finish() {
                        Log.d(TAG, "Length of feed items: " + mFeedItems.size());
                        NotifyDataSetChanged();
                    }
                });
            }
        };
        feedThread.start();
    }
}
