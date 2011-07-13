package org.lantern;

public interface TrustedContactsManager {

    void addTrustedContact(String email);

    boolean isTrusted(String email);

    boolean isJidTrusted(String from);

}
