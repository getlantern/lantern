package org.getlantern.lantern.model;
 
import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.TextView;

import java.util.ArrayList;

import org.getlantern.lantern.R;

class ListAdapter extends BaseAdapter {

    private Context mContext;
    private ArrayList<NavItem> mNavItems;
    private int mLayout;

    public ListAdapter(Context context, ArrayList<NavItem> navItems, int layout) {
        mContext = context;
        mNavItems = navItems;
        mLayout = layout;
    }

    @Override
    public int getCount() {
        return mNavItems.size();
    }

    @Override
    public Object getItem(int position) {
        return mNavItems.get(position);
    }

    @Override
    public long getItemId(int position) {
        return 0;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view;

        if (convertView == null) {
            LayoutInflater inflater = (LayoutInflater) mContext.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            view = inflater.inflate(mLayout, null);
        }
        else {
            view = convertView;
        }

        TextView titleView = (TextView) view.findViewById(R.id.title);
        ImageView iconView = (ImageView) view.findViewById(R.id.icon);

        titleView.setText( mNavItems.get(position).mTitle );
        iconView.setImageResource(mNavItems.get(position).mIcon);

        return view;
    }
}
