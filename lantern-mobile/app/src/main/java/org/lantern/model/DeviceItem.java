package org.lantern.model;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ImageView;
import android.widget.TextView;

import org.lantern.R;

public class DeviceItem extends LinearLayout {

    private ImageView unauthorize;
    public TextView name;

    private void inflateLayout(Context context) {
        LayoutInflater layoutInflater = (LayoutInflater)context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        View view = layoutInflater.inflate(R.layout.device_item, this);
        this.unauthorize = (ImageView)view.findViewById(R.id.unauthorize);
        this.name = (TextView)view.findViewById(R.id.deviceName);
    }

    public DeviceItem(Context context) {
        super(context);
        inflateLayout(context);
    }
}  
