package org.lantern.model;

public class FeedItem {
    private String source;
    private String title;
    private String description;
    private String date;
    private String image;
    private String url;

    public FeedItem(String source, String title, String date, String desc, String image, String url) {
        this.source = source;
        this.title = title;
        this.date = date;
        this.description = desc;
        this.image = image;
        this.url = url;
    }

    public String getSource() {
        return source;
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
 
