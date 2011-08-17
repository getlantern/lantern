package org.lantern;

import java.util.Collection;

public interface TrustedContactsManager {

    void addTrustedContact(String email);

    boolean isTrusted(String email);

    boolean isJidTrusted(String from);

    void addTrustedContacts(Collection<String> trusted);

}
