package org.lantern;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.TreeSet;

import org.codehaus.jackson.annotate.JsonIgnore;
import org.jivesoftware.smack.packet.Presence;

import com.google.common.collect.ImmutableMap;
import com.google.common.eventbus.Subscribe;

/**
 * Class that keeps track of all roster entries.
 */
public class Roster {

    private Map<String, LanternPresence> entries = 
        new HashMap<String, LanternPresence>();
    
    private boolean entriesSet = false;
    
    /**
     * Creates a new roster.
     */
    public Roster() {
        LanternHub.register(this);
    }
    
    @Subscribe
    public void onPresence(final PresenceEvent event) {
        final String email = LanternUtils.jidToEmail(event.getJid());
        if (entries.containsKey(email)) {
            final LanternPresence lp = entries.get(email);
            final Presence pres = event.getPresence();
            lp.setAvailable(pres.isAvailable());
            lp.setStatus(pres.getStatus());
        }
    }
    
    @Subscribe
    public void removePresence(final RemovePresenceEvent event) {
        final String email = LanternUtils.jidToEmail(event.getJid());
        if (entries.containsKey(email)) {
            final LanternPresence lp = entries.get(email);
            lp.setAvailable(false);
            lp.setAway(true);
        }
    }
    
    @Subscribe
    public void onAuthStatus(final AuthenticationStatusEvent ase) {
        final AuthenticationStatus status = ase.getStatus();
        switch (status) {
        case LOGGED_IN:
            setEntriesMap(LanternUtils.getRosterEntries(
                LanternHub.xmppHandler().getP2PClient().getXmppConnection()));
            break;
        case LOGGED_OUT:
            setEntriesMap(new HashMap<String, LanternPresence>());
            break;
        case LOGGING_IN:
            break;
        case LOGGING_OUT:
            break;
        }
    }

    @JsonIgnore
    public void setEntriesMap(final Map<String, LanternPresence> entries) {
        this.setEntriesSet(true);
        synchronized (entries) {
            this.entries = entries;
        }
    }

    @JsonIgnore
    public Map<String, LanternPresence> getEntriesMap() {
        synchronized (entries) {
            return ImmutableMap.copyOf(entries);
        }
    }
    
    public Collection<LanternPresence> getEntries() {
        final Collection<LanternPresence> values;
        synchronized (entries) {
            values = entries.values();
        }
        final TreeSet<LanternPresence> ordered = 
            new TreeSet<LanternPresence>(LanternUtils.PRESENCE_COMPARATOR);
        ordered.addAll(values);
        return ordered;
    }

    public void setEntriesSet(boolean entriesSet) {
        this.entriesSet = entriesSet;
    }

    public boolean isEntriesSet() {
        return entriesSet;
    }
}
