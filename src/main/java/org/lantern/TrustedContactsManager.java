package org.lantern;

import java.util.Collection;

import org.jivesoftware.smack.packet.Packet;

public interface TrustedContactsManager {

    void addTrustedContact(String email);

    boolean isTrusted(String email);
    
    boolean isTrusted(Packet msg);

    boolean isJidTrusted(String from);

    void addTrustedContacts(Collection<String> trusted);

}
