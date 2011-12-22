package org.lantern;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.jivesoftware.smack.packet.Presence;

/**
 * Class that keeps track of all roster entries.
 */
public class Roster implements PresenceListener {

    private Map<String, Presence> entries = 
        new ConcurrentHashMap<String, Presence>();
    
    /**
     * Creates a new roster.
     */
    public Roster() {
        LanternHub.pubSub().addPresenceListener(this);
    }
    
    @Override
    public void onPresence(final String address, final Presence presence) {
        this.entries.put(address, presence);
    }

    @Override
    public void removePresence(final String address) {
        this.entries.remove(address);
    }

    @Override
    public void presencesUpdated() {
        // Nothing to do.
    }

    public void setEntries(final Map<String, Presence> entries) {
        // We ignore stored entries on disk.
    }

    public Map<String, Presence> getEntries() {
        return entries;
    }
}
