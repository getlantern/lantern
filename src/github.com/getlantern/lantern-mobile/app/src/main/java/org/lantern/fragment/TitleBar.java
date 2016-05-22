package org.lantern.fragment;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.res.TypedArray;
import android.graphics.drawable.Drawable;
import android.graphics.Color;             
import android.graphics.PorterDuff;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.View.OnClickListener;
import android.view.View.OnFocusChangeListener;

import org.lantern.R;

import android.support.v4.app.Fragment;
import org.lantern.model.Utils;

public class TitleBar extends Fragment {

    private static final String TAG = "TitleBar";

    private ImageView mBackBtn;
    private ImageView mAvatar;
    private String mTitle;
    private Boolean mDisableBackButton;
    private TextView mTitleHeader;
    private LinearLayout navHeader;
    private Drawable mTitleImage;
    private Drawable mBackground;
    private Integer mTextColor = 0;
    private int onColor, offColor;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {

        View view = inflater.inflate(R.layout.titlebar, container, true);

        if (mDisableBackButton == null || !mDisableBackButton.booleanValue()) {
            mBackBtn = (ImageView)view.findViewById(R.id.avatar);

            mBackBtn.setOnClickListener(new View.OnClickListener() {

                @Override
                public void onClick(View v) {
                    Log.d(TAG, "Back button pressed");
                    Activity activity = getActivity();
                    activity.finish();
                }
            });
        }

        if (mTitle != null) {
            mTitleHeader = (TextView)view.findViewById(R.id.header);
            mTitleHeader.setText(mTitle);
            if (mTextColor != 0) {
                mTitleHeader.setTextColor(mTextColor);
            }
        }

        if (mBackground != null) {
            navHeader = (LinearLayout)view.findViewById(R.id.navHeader);
            navHeader.setBackground(mBackground);
        }

        mAvatar = (ImageView)view.findViewById(R.id.avatar);
        if (mTitleImage != null) {
            mAvatar.setImageDrawable(mTitleImage);
        } else {
            final Drawable backArrow = getResources().getDrawable(R.drawable.abc_ic_ab_back_mtrl_am_alpha);
            backArrow.setColorFilter(getResources().getColor(R.color.black), PorterDuff.Mode.SRC_ATOP);
            if (backArrow != null) {
                mAvatar.setImageDrawable(backArrow);
            }
        }


        return view;
    }

    @Override
    public void onInflate(Activity activity, AttributeSet attrs, Bundle savedInstanceState) {

        super.onInflate(activity, attrs, savedInstanceState);

        TypedArray a = activity.obtainStyledAttributes(attrs,
                R.styleable.TitleBar);

        onColor = activity.getResources().getColor(R.color.blue_color);
        offColor = activity.getResources().getColor(R.color.accent_white);

        mTitle = a.getString(R.styleable.TitleBar_titleText);
        mDisableBackButton = a.getBoolean(R.styleable.TitleBar_disableBackButton, false);
        mBackground = a.getDrawable(R.styleable.TitleBar_backgroundColor);
        mTitleImage = a.getDrawable(R.styleable.TitleBar_titleImage);
        mTextColor  = a.getColor(R.styleable.TitleBar_textColor, 0);
    }

    public void setOnClickListener(
            android.view.View.OnClickListener onClick) {
        if (mAvatar != null) {
            mAvatar.setOnClickListener(onClick);
        }
    }

    public void switchLantern(int imageRes, boolean on) {
        if (mAvatar != null) {
            mAvatar.setImageResource(imageRes);
            //navHeader.setBackgroundColor(on ? onColor : offColor);
            mTitleHeader.setTextColor(on ? offColor : onColor);
        }
    }

    public void setTitle(String title) {
        if (mTitleHeader != null) {
            mTitleHeader.setText(title);
        }
    }
}
 
