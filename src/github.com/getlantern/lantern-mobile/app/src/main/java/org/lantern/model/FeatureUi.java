package org.lantern.model;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ImageView;
import android.widget.TextView;

import org.lantern.R;

public class FeatureUi extends LinearLayout {

    private ImageView checkmark;
    public TextView text;

    private void inflateLayout(Context context) {
        LayoutInflater layoutInflater = (LayoutInflater)context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        View view = layoutInflater.inflate(R.layout.pro_feature, this);
        this.checkmark = (ImageView)view.findViewById(R.id.checkmark);
        this.text = (TextView)view.findViewById(R.id.feature_text);
    }

    public FeatureUi(Context context) {
        super(context);
        inflateLayout(context);
    }
}
