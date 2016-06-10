package org.getlantern.lantern.model;

public class FeedItem {
    private String title;
    private String description;
    private String image;
    private String url;

    public FeedItem(String mTitle, String mDesc, String mImage, String mUrl) {
        title = mTitle;
        description = mDesc;
        image = mImage;
        url = mUrl;
    }

    public String getTitle() {
        return title;
    }

    public String getImage() {
        return image;
    }                

    public String getDescription() {
        return description;
    }               
 
    public String getUrl() {
        return url;
    }                     
}
 
