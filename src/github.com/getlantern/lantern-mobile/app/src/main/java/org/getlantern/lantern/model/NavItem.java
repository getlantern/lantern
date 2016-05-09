package org.getlantern.lantern.model;

public class NavItem {
    String mTitle;
    int mIcon;

    public NavItem(String title, int icon) {
        mTitle = title;
        mIcon = icon;
    }

    public String getTitle() {
        return mTitle;
    }

    public void setTitle(String title) {
        this.mTitle = title;
    }
}

