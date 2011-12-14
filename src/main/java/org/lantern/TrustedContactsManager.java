package org.lantern;

import java.util.Collection;

import org.jivesoftware.smack.packet.Packet;

/**
 * Interface for classes that manage the trusted Lantern contacts for the
 * current user.
 */
public interface TrustedContactsManager {

    void addTrustedContact(String email);
    
    void removeTrustedContact(String email);

    boolean isTrusted(String email);
    
    boolean isTrusted(Packet msg);

    boolean isJidTrusted(String from);

    void addTrustedContacts(Collection<String> trusted);
    
    void removeTrustedContacts(Collection<String> trusted);

}
