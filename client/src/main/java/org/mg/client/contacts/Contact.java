package org.mg.client.contacts;

import com.google.api.client.util.DateTime;
import com.google.api.client.util.Key;

/**
 * Data for a single contact.
 */
public class Contact {
    
    @Key
    public String id;
    
    @Key
    public String title;
    
    @Key
    public DateTime updated;
    
    @Key("gd:email")
    public Email email;
}