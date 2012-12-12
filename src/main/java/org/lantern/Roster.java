package org.lantern;

import java.io.IOException;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentSkipListMap;

import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.codehaus.jackson.map.annotate.JsonView;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.RosterPacket.Item;
import org.kaleidoscope.BasicRandomRoutingTable;
import org.kaleidoscope.BasicTrustGraphNodeId;
import org.kaleidoscope.RandomRoutingTable;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.lantern.event.UpdatePresenceEvent;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Profile;
import org.lantern.state.StaticSettings;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.ImmutableSortedSet;
import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class that keeps track of all roster entries.
 */
@Singleton
public class Roster implements RosterListener {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private Map<String, LanternRosterEntry> rosterEntries = 
        new ConcurrentSkipListMap<String, LanternRosterEntry>();
    
    /**
     * Map of e-mail address of the requester to their full profile.
     */
    private final Map<String, Profile> incomingSubscriptionRequests = 
        new TreeMap<String, Profile>();

    private volatile boolean populated;
    
    
    private final RandomRoutingTable kscopeRoutingTable = 
        new BasicRandomRoutingTable();

    private org.jivesoftware.smack.Roster smackRoster;
    
    
    /**
     * Locally-stored set of users we've invited.
     */
    private Set<String> invited = new HashSet<String>();

    /**
     * Creates a new roster.
     */
    @Inject
    public Roster() {
        Events.register(this);
    }

    public void onRoster(final org.jivesoftware.smack.Roster roster) {
        log.info("Got logged in event");
        // Threaded to avoid this holding up setting the logged-in state in
        // the UI.
        this.smackRoster = roster;
        final Runnable r = new Runnable() {
            @Override
            public void run() {
                roster.setSubscriptionMode(
                    org.jivesoftware.smack.Roster.SubscriptionMode.manual);
                roster.addRosterListener(Roster.this);
                final Collection<RosterEntry> unordered = 
                    roster.getEntries();
                log.debug("Got roster entries!!");
                
                rosterEntries = getRosterEntries(unordered);
                
                for (final RosterEntry entry : unordered) {
                    final Iterator<Presence> presences = 
                        roster.getPresences(entry.getUser());
                    while (presences.hasNext()) {
                        final Presence p = presences.next();
                        processPresence(p, false);
                    }
                }
                populated = true;
                log.debug("Finished populating roster");
                log.info("kscope is: {}", kscopeRoutingTable);
                Events.syncRoster(Roster.this);
            }
        };
        final Thread t = new Thread(r, "Roster-Populating-Thread");
        t.setDaemon(true);
        t.start();
    }
    
    /*
    public Collection<LanternRosterEntry> getRosterEntries(
        final String email, final String pwd, final int attempts) 
        throws IOException, CredentialException {
        final XMPPConnection conn = 
            XmppUtils.persistentXmppConnection(email, pwd, "lantern", attempts);
        return getRosterEntries(conn);
    }

    public Collection<LanternRosterEntry> getRosterEntries(
        final XMPPConnection xmppConnection) {
        final RosterPacket msg = XmppUtils.extendedRoster(xmppConnection);
        return getRosterEntriesByItems(msg.getRosterItems());
    }
    */

    private Collection<LanternRosterEntry> getRosterEntriesByItems(
        final Collection<Item> unordered) {
        final Collection<LanternRosterEntry> entries = 
            new TreeSet<LanternRosterEntry>();
        for (final Item entry : unordered) {
            final LanternRosterEntry lp = 
                new LanternRosterEntry(entry, photoUrlBase(), this);
            final boolean added = entries.add(lp);
            if (!added) {
                log.warn("DID NOT ADD {}", entry);
                log.warn("ENTRIES: {}", entries);
            }
        }
        return entries;
    }

    private String photoUrlBase() {
        return StaticSettings.getLocalEndpoint()+"/photo/";
    }

    private Map<String, LanternRosterEntry> getRosterEntries(
        final Collection<RosterEntry> unordered) {
        final Map<String, LanternRosterEntry> entries = 
            new ConcurrentSkipListMap<String, LanternRosterEntry>();
        for (final RosterEntry entry : unordered) {
            final LanternRosterEntry lp = 
                new LanternRosterEntry(entry, photoUrlBase(), this);
            if (LanternUtils.isNotJid(lp.getUserId())) {
                entries.put(lp.getUserId(), lp);
            }
        }
        return entries;
    }
    
    private void processPresence(final Presence presence, final boolean sync) {
        final String from = presence.getFrom();
        log.debug("Got presence: {}", presence.toXML());
        if (LanternUtils.isLanternHub(from)) {
            log.info("Got Lantern hub presence");
        } else if (LanternUtils.isLanternJid(from)) {
            //this.xmppHandler.addOrRemovePeer(presence, from);
            Events.eventBus().post(new UpdatePresenceEvent(presence));
            final TrustGraphNodeId id = new BasicTrustGraphNodeId(from);
            this.kscopeRoutingTable.addNeighbor(id);
            onPresence(presence, sync);
        } else {
            onPresence(presence, sync);
        }
    }
    
    private void onPresence(final Presence pres, final boolean sync) {
        final String email = LanternUtils.jidToEmail(pres.getFrom());
        final LanternRosterEntry entry = this.rosterEntries.get(email);
        if (entry != null) {
            entry.setAvailable(pres.isAvailable());
            entry.setStatus(pres.getStatus());
        } else {
            // This may be someone we have subscribed to who we're just now
            // getting the presence for.
            log.info("Adding non-roster presence: {}", email);
            addEntry(new LanternRosterEntry(pres, photoUrlBase(), this));
        }
        
        if (sync) {
            Events.syncRoster(this);
        }
    }

    private void addEntry(final LanternRosterEntry pres) {
        if (LanternUtils.isNotJid(pres.getUserId())) {
            log.info("Adding entry for {}", pres);
            rosterEntries.put(pres.getUserId(), pres);
            
        } else {
            log.info("Not adding entry for {}", pres);
        }
        
        log.info("Finished adding entry for {}", pres);
        //if (LanternUtils.isLanternJid(pres.getEmail()))
        //this.kscopeRoutingTable
    }
    
    //@JsonUnwrapped
    public Collection<LanternRosterEntry> getEntries() {
        synchronized (this.rosterEntries) {
            return ImmutableSortedSet.copyOf(this.rosterEntries.values());
        }
    }

    public void addIncomingSubscriptionRequest(final Presence pres) {
        final String json = (String) pres.getProperty(XmppMessageConstants.PROFILE);
        if (StringUtils.isBlank(json)) {
            log.warn("No profile?");
            return;
        }
        final ObjectMapper mapper = new ObjectMapper();
        try {
            final Profile prof = mapper.readValue(json, Profile.class);
            incomingSubscriptionRequests.put(prof.getEmail(), prof);
            Events.syncRoster(this);
        } catch (final JsonParseException e) {
            log.warn("Error parsing json", e);
        } catch (final JsonMappingException e) {
            log.warn("Error mapping json", e);
        } catch (final IOException e) {
            log.warn("Error reading json", e);
        }
    }
    

    public void removeIncomingSubscriptionRequest(final String from) {
        final String email = XmppUtils.jidToUser(from);
        incomingSubscriptionRequests.remove(email);
        Events.syncRoster(this);
    }

    public Collection<Profile> getSubscriptionRequests() {
        synchronized (incomingSubscriptionRequests) {
            return incomingSubscriptionRequests.values();
        }
    }

    @Override
    public void entriesAdded(final Collection<String> entries) {
        log.debug("Adding {} entries to roster", entries.size());
        for (final String entry : entries) {
            addEntry(new LanternRosterEntry(entry, photoUrlBase(), this));
        }
        Events.syncRoster(this);
    }

    @Override
    public void entriesDeleted(final Collection<String> entries) {
        log.debug("Roster entries deleted: {}", entries);
        for (final String entry : entries) {
            final String email = LanternUtils.jidToEmail(entry);
            // We remove both because we're not sure what form it's 
            // stored in.
            rosterEntries.remove(email);
            rosterEntries.remove(entry);
        }
        Events.syncRoster(this);
    }

    @Override
    public void entriesUpdated(final Collection<String> entries) {
        log.debug("Entries updated: {} for roster: {}", entries, this);
        if (this.smackRoster == null) {
            log.error("No roster yet?");
            return;
        }
        for (final String entry : entries) {
            final Presence pres = this.smackRoster.getPresence(entry);
            onPresence(pres, false);
        }
        Events.syncRoster(this);
    }

    @Override
    public void presenceChanged(final Presence pres) {
        log.debug("Got presence changed event.");
        processPresence(pres, true);
        //LanternHub.asyncEventBus().post(new RosterStateChangedEvent());
    }
    

    public boolean populated() {
        return this.populated;
    }
    
    public void reset() {
        this.incomingSubscriptionRequests.clear();
        this.rosterEntries.clear();
        this.kscopeRoutingTable.clear();
        this.populated = false;
    }

    /**
     * Returns whether or not the given peer is on the roster with no pending
     * subscription states.
     * 
     * @param email The email of the peer.
     * @return <code>true</code> if the peer is on the roster with no pending
     * subscription states, otherwise <code>false</code>.
     */
    public boolean isFullyOnRoster(final String email) {
        final LanternRosterEntry entry = this.rosterEntries.get(email);
        if (entry == null) {
            return false;
        }
        final String subscriptionStatus = entry.getSubscriptionStatus();
        
        // If we're not still trying to subscribe or unsubscribe to this node,
        // then it is a legitimate entry.
        if (StringUtils.isBlank(subscriptionStatus)) {
            return true;
        } 
        
        return false;
    }
    
    public boolean autoAcceptSubscription(final String from) {
        final LanternRosterEntry entry = this.rosterEntries.get(from);
        if (entry == null) {
            return false;
        }
        final String subscriptionStatus = entry.getSubscriptionStatus();
        
        // If we're not still trying to subscribe or unsubscribe to this node,
        // then it is a legitimate entry.
        if (StringUtils.isBlank(subscriptionStatus)) {
            return true;
        } 
        
        // Otherwise only auto-allow subscription requests if we've requested
        // to subscribe to them.
        return subscriptionStatus.equalsIgnoreCase("subscribe");
    }
    
    @Subscribe
    public void onReset(final ResetEvent event) {
        reset();
    }
    
    public void setInvited(final Set<String> invited) {
        this.invited = invited;
    }
    
    @JsonView({Persistent.class})
    public Set<String> getInvited() {
        return invited;
    }
}
