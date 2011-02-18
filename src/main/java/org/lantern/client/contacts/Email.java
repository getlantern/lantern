package org.lantern.client.contacts;

import com.google.api.client.util.Key;

/**
 * E-mail address for a Google contact.
 */
public class Email {
    
    @Key("@address")
    public String address;
}