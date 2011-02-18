package org.lantern.contacts;

import java.io.IOException;
import java.util.Collection;
import java.util.Scanner;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.Logger;


import com.google.api.client.googleapis.GoogleTransport;
import com.google.api.client.googleapis.auth.clientlogin.ClientLogin;
import com.google.api.client.http.HttpResponseException;
import com.google.api.client.xml.atom.AtomParser;
import com.google.api.data.contacts.v3.GoogleContacts;
import com.google.api.data.contacts.v3.atom.GoogleContactsAtom;

/**
 * Default implementation of the contacts API.
 */
public class DefaultContacts implements Contacts {

    public static void main(final String[] args) throws IOException {
        enableLogging();
        Scanner s = new Scanner(System.in);
        System.out.println("Username: ");
        final String username = s.nextLine();
        System.out.println("Password: ");
        final String password = s.nextLine();
        
        final Contacts contacts = new DefaultContacts();
        final Collection<Contact> all = 
            contacts.getAllContacts(username, password);
        System.out.println("Total number of contacts: " + all.size());
        for (final Contact contact : all) {
            showContact(contact);
        }
    }
    
    public Collection<Contact> getAllContacts(final String username, 
        final String password) throws IOException {
        try {
            final ClientLogin authenticator = new ClientLogin();
            authenticator.authTokenType = GoogleContacts.AUTH_TOKEN_TYPE;
            authenticator.username = username;
            authenticator.password = password;
            final GoogleTransport transport = setUpGoogleTransport();
            authenticator.authenticate().setAuthorizationHeader(transport);
            
            final String path;
            if (username.trim().endsWith("gmail.com")) {
                path = username + "/full";
            }
            else {
                path = username+"@gmail.com/full";
            }
            final ContactsUrl url = new ContactsUrl(
                "http://www.google.com/m8/feeds/contacts/"+path);
            url.maxResults = 3000;
            final ContactsFeed feed = ContactsFeed.executeGet(transport, url);
            return feed.entries;
        } catch (final HttpResponseException e) {
            throw new IOException("Could not access contacts!!", e);
        } finally {
        }
    }

    private static void showContact(final Contact contact) {
        System.out.println(contact.title);
        if (contact.email != null) {
            System.out.println(contact.email.address);
        }
    }

    private static GoogleTransport setUpGoogleTransport() {
        final GoogleTransport transport = new GoogleTransport();
        transport.applicationName = "google-youtubejsoncsample-1.0";
        transport.setVersionHeader(GoogleContacts.VERSION);
        final AtomParser parser = new AtomParser();
        parser.namespaceDictionary = GoogleContactsAtom.NAMESPACE_DICTIONARY;
        transport.addParser(parser);
        return transport;
    }

    private static void enableLogging() {
        Logger logger = Logger.getLogger("com.google.api.client");
        logger.setLevel(Level.ALL);
        logger.addHandler(new Handler() {

            @Override
            public void close() throws SecurityException {
            }

            @Override
            public void flush() {
            }

            @Override
            public void publish(LogRecord record) {
                // default ConsoleHandler will take care of >= INFO
                if (record.getLevel().intValue() < Level.INFO.intValue()) {
                    System.out.println(record.getMessage());
                }
            }
        });
    }

}
