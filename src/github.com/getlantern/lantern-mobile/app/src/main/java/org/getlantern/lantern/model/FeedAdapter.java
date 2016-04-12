package org.getlantern.lantern.model;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
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
 
import org.getlantern.lantern.R;

public class FeedAdapter extends BaseAdapter {

	private static final String TAG = "FeedAdapter";
	private static final int IO_BUFFER_SIZE = 4 * 1024;

	private Context mContext;
	private ArrayList<FeedItem> mFeedItems;

	private LruCache<String, Bitmap> mMemoryCache;

    public FeedAdapter(Context context, ArrayList<FeedItem> feedItems) {
        mContext = context;
        mFeedItems = feedItems;

		final int maxMemory = (int) (Runtime.getRuntime().maxMemory() / 1024);

		// Use 1/8th of the available memory for this memory cache.
		final int cacheSize = maxMemory / 8;

		mMemoryCache = new LruCache<String, Bitmap>(cacheSize) {
			@Override
			protected int sizeOf(String key, Bitmap bitmap) {
				// The cache size will be measured in kilobytes rather than
				// number of items.
				return bitmap.getByteCount() / 1024;
			}
		};
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
 

	public void addBitmapToMemoryCache(String key, Bitmap bitmap) {
		if (getBitmapFromMemCache(key) == null) {
			if (bitmap != null) {
				mMemoryCache.put(key, bitmap);
			}
		}
	}

	public Bitmap getBitmapFromMemCache(String key) {
		return mMemoryCache.get(key);
	}
	

	public void loadBitmap(String url, ImageView imgView) {
		Bitmap bitmap = null;
		InputStream in = null;
		BufferedOutputStream out = null;

		final Bitmap cached = getBitmapFromMemCache(url);
		if (cached != null) {
			imgView.setImageBitmap(cached);
       		return;
		}

		try {
			in = new BufferedInputStream(new URL(url).openStream(), IO_BUFFER_SIZE);

			final ByteArrayOutputStream dataStream = new ByteArrayOutputStream();
			out = new BufferedOutputStream(dataStream, IO_BUFFER_SIZE);
			copy(in, out);
			out.flush();

			final byte[] data = dataStream.toByteArray();
			BitmapFactory.Options options = new BitmapFactory.Options();
			//options.inSampleSize = 1;

			bitmap = BitmapFactory.decodeByteArray(data, 0, data.length,options);
		} catch (IOException e) {
			Log.e(TAG, "Could not load Bitmap from: " + url);
		} finally {
			closeStream(in);
			closeStream(out);
		}

		addBitmapToMemoryCache(url, bitmap);
		imgView.setImageBitmap(bitmap);
	}

	private static void copy(InputStream in, OutputStream out) throws IOException {
		byte[] b = new byte[IO_BUFFER_SIZE];
		int read;
		while ((read = in.read(b)) != -1) {
			out.write(b, 0, read);
		}
	}

	private static void closeStream(Closeable stream) {
		if (stream != null) {
			try {
				stream.close();
			} catch (IOException e) {
				Log.e(TAG, "Could not close stream", e);
			}
		}
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

		if (item.Image.equals("")) {
       		item.Image = "http://www2.warwick.ac.uk/fac/soc/economics/apps/templates/external_article_placeholder.jpg";
		}

		loadBitmap(item.Image, imageView);
        return view;
    }        

}
