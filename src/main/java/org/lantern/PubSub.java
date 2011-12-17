package org.lantern;

import org.jivesoftware.smack.packet.Presence;

/**
 * Interface for classes allowing callers to subscribe to events and to be 
 * notified of them.
 */
public interface PubSub {

    void addUpdate(LanternUpdate lanternUpdate);
    
    void addUpdateListener(LanternUpdateListener updateListener);

    void addPresence(String from, Presence presence);
    
    void addPresenceListener(PresenceListener presenceListener);

    void removePresence(String address);

    void addConnectivityListener(ConnectivityListener cl);

    void setConnectivityStatus(ConnectivityStatus ct);

}
