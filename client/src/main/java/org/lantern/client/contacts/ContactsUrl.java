package org.lantern.client.contacts;

import com.google.api.client.googleapis.GoogleUrl;
import com.google.api.client.util.Key;

public class ContactsUrl extends GoogleUrl {

    @Key("max-results")
    public Integer maxResults;

    public ContactsUrl(String encodedUrl) {
        super(encodedUrl);
    }
}
