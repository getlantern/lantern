package org.lantern;

import org.jivesoftware.smack.packet.Presence;

/**
 * Listener for changes to the presence of peers.
 */
public interface PresenceListener {

    void onPresence(String address, Presence presence);

    void removePresence(String address);

    void presencesUpdated();

}
