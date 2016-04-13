package org.getlantern.lantern.model;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.AsyncTask;
import android.util.Log;
import android.util.LruCache;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import java.io.ByteArrayOutputStream;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.Closeable;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;
import java.util.ArrayList;

import java.net.URL;
import java.lang.ref.WeakReference;

import org.getlantern.lantern.R;

import com.koushikdutta.ion.Ion;

public class FeedAdapter extends BaseAdapter {

    private static final String TAG = "FeedAdapter";
    private static final int IO_BUFFER_SIZE = 4 * 1024;

    private Context mContext;
    private ArrayList<FeedItem> mFeedItems;


    public FeedAdapter(Context context, ArrayList<FeedItem> feedItems) {
        mContext = context;
        mFeedItems = feedItems;
    }

    @Override
    public long getItemId(int position) {
        return 0;
    }


    @Override
    public int getCount() {
        return mFeedItems.size();
    }

    @Override
    public Object getItem(int position) {
        return mFeedItems.get(position);
    }


    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view;

        if (convertView == null) {
            LayoutInflater inflater = (LayoutInflater) mContext.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            view = inflater.inflate(R.layout.feed_item, parent, false);
        }
        else {
            view = convertView;
        }

        TextView titleView = (TextView) view.findViewById(R.id.title);
        TextView descView = (TextView)view.findViewById(R.id.description);
        TextView urlView = (TextView)view.findViewById(R.id.link);

        ImageView imageView = (ImageView) view.findViewById(R.id.image);

        FeedItem item = mFeedItems.get(position);
        titleView.setText( item.Title);
        descView.setText(item.Description);
        urlView.setText(item.Url);

        if (item.Image != "") {
            Ion.with(mContext)
                .load(item.Image)
                .withBitmap()
                .intoImageView(imageView);
        }
        //loadBitmap(item.Image, imageView);
        return view;
    }        
}
