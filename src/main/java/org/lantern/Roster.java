package org.lantern;

import java.io.IOException;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentSkipListMap;

import javax.security.auth.login.CredentialException;

import org.apache.commons.lang3.StringUtils;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.RosterPacket;
import org.jivesoftware.smack.packet.RosterPacket.Item;
import org.kaleidoscope.BasicRandomRoutingTable;
import org.kaleidoscope.BasicTrustGraphNodeId;
import org.kaleidoscope.RandomRoutingTable;
import org.kaleidoscope.TrustGraphNodeId;
import org.littleshoot.commom.xmpp.XmppP2PClient;
import org.littleshoot.commom.xmpp.XmppUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.collect.ImmutableSortedSet;

/**
 * Class that keeps track of all roster entries.
 */
public class Roster implements RosterListener {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private Map<String, LanternRosterEntry> rosterEntries = 
        new ConcurrentSkipListMap<String, LanternRosterEntry>();
    
    private final Collection<String> incomingSubscriptionRequests = 
        new HashSet<String>();

    private final XmppHandler xmppHandler;

    private volatile boolean populated;
    
    
    private final RandomRoutingTable kscopeRoutingTable = 
        new BasicRandomRoutingTable();
    
    /**
     * Creates a new roster.
     */
    public Roster(final XmppHandler xmppHandler) {
        this.xmppHandler = xmppHandler;
    }

    public void loggedIn() {
        log.info("Got logged in event");
        // Threaded to avoid this holding up setting the logged-in state in
        // the UI.
        final Runnable r = new Runnable() {
            @Override
            public void run() {
                final XMPPConnection conn = 
                    xmppHandler.getP2PClient().getXmppConnection();
                
                final org.jivesoftware.smack.Roster roster = conn.getRoster();
                roster.setSubscriptionMode(
                    org.jivesoftware.smack.Roster.SubscriptionMode.manual);
                roster.addRosterListener(Roster.this);
                final Collection<RosterEntry> unordered = roster.getEntries();
                log.debug("Got roster entries!!");
                
                rosterEntries = getRosterEntries(unordered);
                
                for (final RosterEntry entry : unordered) {
                    final Iterator<Presence> presences = 
                        roster.getPresences(entry.getUser());
                    while (presences.hasNext()) {
                        final Presence p = presences.next();
                        processPresence(p);
                    }
                }
                populated = true;
                log.debug("Finished populating roster");
                log.info("kscope is: {}", kscopeRoutingTable);
                LanternHub.asyncEventBus().post(new RosterStateChangedEvent());
            }
        };
        final Thread t = new Thread(r, "Roster-Populating-Thread");
        t.setDaemon(true);
        t.start();
    }
    
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

    private Collection<LanternRosterEntry> getRosterEntriesByItems(
        final Collection<Item> unordered) {
        final Collection<LanternRosterEntry> entries = 
            new TreeSet<LanternRosterEntry>();
        for (final Item entry : unordered) {
            final LanternRosterEntry lp = new LanternRosterEntry(entry);
            final boolean added = entries.add(lp);
            if (!added) {
                log.warn("DID NOT ADD {}", entry);
                log.warn("ENTRIES: {}", entries);
            }
        }
        return entries;
    }

    private Map<String, LanternRosterEntry> getRosterEntries(
        final Collection<RosterEntry> unordered) {
        final Map<String, LanternRosterEntry> entries = 
            new ConcurrentSkipListMap<String, LanternRosterEntry>();
        for (final RosterEntry entry : unordered) {
            final LanternRosterEntry lp = new LanternRosterEntry(entry);
            if (LanternUtils.isNotJid(lp.getEmail())) {
                entries.put(lp.getEmail(), lp);
            }
        }
        return entries;
    }
    
    private void processPresence(final Presence presence) {
        final String from = presence.getFrom();
        log.debug("Got presence: {}", presence.toXML());
        if (LanternUtils.isLanternHub(from)) {
            log.info("Got Lantern hub presence");
        } else if (LanternUtils.isLanternJid(from)) {
            this.xmppHandler.addOrRemovePeer(presence, from);
            final TrustGraphNodeId id = new BasicTrustGraphNodeId(from);
            this.kscopeRoutingTable.addNeighbor(id);
            onPresence(presence);
        } else {
            onPresence(presence);
        }
    }
    
    private void onPresence(final Presence pres) {
        final String email = LanternUtils.jidToEmail(pres.getFrom());
        final LanternRosterEntry entry = this.rosterEntries.get(email);
        if (entry != null) {
            entry.setAvailable(pres.isAvailable());
            entry.setStatus(pres.getStatus());
        } else {
            // This may be someone we have subscribed to who we're just now
            // getting the presence for.
            log.info("Adding non-roster presence: {}", email);
            addEntry(new LanternRosterEntry(pres));
        }
    }

    private void addEntry(final LanternRosterEntry pres) {
        if (LanternUtils.isNotJid(pres.getEmail())) {
            log.info("Adding entry for {}", pres);
            rosterEntries.put(pres.getEmail(), pres);
            
        } else {
            log.info("Not adding entry for {}", pres);
        }
        
        log.info("Finished adding entry for {}", pres);
        //if (LanternUtils.isLanternJid(pres.getEmail()))
        //this.kscopeRoutingTable
    }
    
    public Collection<LanternRosterEntry> getEntries() {
        synchronized (this.rosterEntries) {
            return ImmutableSortedSet.copyOf(this.rosterEntries.values());
        }
    }

    public void addIncomingSubscriptionRequest(final String from) {
        incomingSubscriptionRequests.add(from);
        LanternHub.asyncEventBus().post(new RosterStateChangedEvent());
    }
    

    public void removeIncomingSubscriptionRequest(final String from) {
        incomingSubscriptionRequests.remove(from);
        LanternHub.asyncEventBus().post(new RosterStateChangedEvent());
    }

    public Collection<String> getSubscriptionRequests() {
        return incomingSubscriptionRequests;
    }

    @Override
    public void entriesAdded(final Collection<String> entries) {
        log.debug("Adding {} entries to roster", entries.size());
        for (final String entry : entries) {
            addEntry(new LanternRosterEntry(entry));
        }
        LanternHub.asyncEventBus().post(new RosterStateChangedEvent());
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
        LanternHub.asyncEventBus().post(new RosterStateChangedEvent());
    }

    @Override
    public void entriesUpdated(final Collection<String> entries) {
        log.debug("Entries updated: {} for roster: {}", entries, this);
        for (final String entry : entries) {
            final Presence pres = 
                this.xmppHandler.getP2PClient().getXmppConnection().getRoster().getPresence(entry);
            onPresence(pres);
        }
        LanternHub.asyncEventBus().post(new RosterStateChangedEvent());
    }

    @Override
    public void presenceChanged(final Presence pres) {
        log.debug("Got presence changed event.");
        processPresence(pres);
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
    
    
    @Override
    public String toString() {
        String id = "";
        final XmppP2PClient client = this.xmppHandler.getP2PClient();
        if (client != null) {
            final XMPPConnection conn = client.getXmppConnection();
            id = conn.getUser();
        }
        return "Roster for "+id+" [rosterEntries=" + rosterEntries + "]";
    }
}
