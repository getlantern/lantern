package org.lantern;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.jivesoftware.smack.packet.Presence;

import com.google.common.eventbus.Subscribe;

/**
 * Class that keeps track of all roster entries.
 */
public class Roster {

    private Map<String, Presence> entries = 
        new ConcurrentHashMap<String, Presence>();
    
    /**
     * Creates a new roster.
     */
    public Roster() {
        LanternHub.eventBus().register(this);
    }
    
    @Subscribe
    public void onPresence(final AddPresenceEvent event) {
        this.entries.put(event.getJid(), event.getPresence());
    }

    @Subscribe
    public void removePresence(final RemovePresenceEvent event) {
        this.entries.remove(event.getJid());
    }

    public void setEntries(final Map<String, Presence> entries) {
        // We ignore stored entries on disk.
    }

    public Map<String, Presence> getEntries() {
        return entries;
    }
}
