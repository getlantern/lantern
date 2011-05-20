package org.lantern.contacts;

import java.io.IOException;
import java.util.List;

import com.google.api.client.googleapis.GoogleTransport;
import com.google.api.client.googleapis.GoogleUrl;
import com.google.api.client.http.HttpRequest;
import com.google.api.client.util.Key;

/**
 * Feed for Google Contacts.
 */
public class ContactsFeed {

    @Key("openSearch:totalResults")
    public int totalResults;
    
    @Key("entry")
    public List<Contact> entries;

    public static ContactsFeed executeGet(final GoogleTransport transport,
        final GoogleUrl url) throws IOException {
        final HttpRequest request = transport.buildGetRequest();
        request.url = url;
        return request.execute().parseAs(ContactsFeed.class);
    }
}
