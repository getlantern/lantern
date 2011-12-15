package org.lantern;

import org.jivesoftware.smack.packet.Presence;

/**
 * Class that keeps track of listeners and notifying listeners for various
 * operations. Allows listeners to be more loosely coupled to classes 
 * generating events.
 */
public interface Notifier {

    void addUpdate(LanternUpdate lanternUpdate);
    
    void addUpdateListener(LanternUpdateListener updateListener);

    void addPresence(String from, Presence presence);
    
    void addPresenceListener(PresenceListener presenceListener);

    void removePresence(String address);

}
