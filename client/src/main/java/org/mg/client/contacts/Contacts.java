package org.mg.client.contacts;

import java.io.IOException;
import java.util.Collection;


/**
 * Interface for accessing Google contacts.
 */
public interface Contacts {

    /**
     * Accesses all contacts for a given user.
     * 
     * @param username The user name to access contacts for.
     * @param password The user's password.
     * @return The {@link Collection} of contacts for the specified user.
     * @throws IOException If there's an error accessing the API.
     */
    Collection<Contact> getAllContacts(String username, String password) 
        throws IOException;
}
