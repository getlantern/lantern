package org.lantern.model;

import android.content.res.Resources;
import org.lantern.R;

public class NavItem {
    private String title;
    private int icon;

    public NavItem(String title, int icon) {
        this.title = title;
        this.icon = icon;
    }

    public String getTitle() {
        return title;
    }

    public int getIcon() {
        return icon;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public boolean newsFeedItem(Resources res) {
        if (title == null) {
            return false;
        }

        return title.equals(res.getString(R.string.newsfeed_off_option)) ||
            title.equals(res.getString(R.string.newsfeed_option));
    }
}

