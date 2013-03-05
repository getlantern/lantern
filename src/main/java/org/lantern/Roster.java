package org.lantern;

import java.net.InetAddress;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentSkipListMap;

import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.map.annotate.JsonView;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Presence;
import org.kaleidoscope.BasicTrustGraphAdvertisement;
import org.kaleidoscope.BasicTrustGraphNodeId;
import org.kaleidoscope.RandomRoutingTable;
import org.kaleidoscope.TrustGraphNode;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.lantern.event.UpdatePresenceEvent;
import org.lantern.kscope.LanternKscopeAdvertisement;
import org.lantern.kscope.LanternTrustGraphNode;
import org.lantern.state.Model;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Settings;
import org.lantern.state.SyncPath;
import org.lastbamboo.common.ice.MappedServerSocket;
import org.lastbamboo.common.stun.client.PublicIpAddress;
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
    //private final Map<String, Profile> incomingSubscriptionRequests =
      //  new TreeMap<String, Profile>();

    private final RandomRoutingTable kscopeRoutingTable;
    private final XmppHandler xmppHandler;
    private final Model model;

    private org.jivesoftware.smack.Roster smackRoster;

    /**
     * Locally-stored set of users we've invited.
     */
    private Set<String> invited = new HashSet<String>();

    /**
     * Creates a new roster.
     */
    @Inject
    public Roster(final RandomRoutingTable routingTable, 
            final XmppHandler xmppHandler,
            final Model model) {
        this.kscopeRoutingTable = routingTable;
        this.xmppHandler = xmppHandler;
        this.model = model;
        model.setRoster(this);
        Events.register(this);
    }

    public void onRoster(final XMPPConnection conn) {
        log.info("Got logged in event");
        // Threaded to avoid this holding up setting the logged-in state in
        // the UI.
        final org.jivesoftware.smack.Roster ros = conn.getRoster();
        this.smackRoster = ros;
        final Runnable r = new Runnable() {
            @Override
            public void run() {
                ros.setSubscriptionMode(
                    org.jivesoftware.smack.Roster.SubscriptionMode.manual);
                ros.addRosterListener(Roster.this);
                final Collection<RosterEntry> unordered = ros.getEntries();
                log.debug("Got roster entries!!");

                rosterEntries = getRosterEntries(unordered);

                for (final RosterEntry entry : unordered) {
                    final Iterator<Presence> presences =
                        ros.getPresences(entry.getUser());
                    while (presences.hasNext()) {
                        final Presence p = presences.next();
                        processPresence(p, false, false);
                    }
                }
                log.debug("Finished populating roster");
                log.info("kscope is: {}", kscopeRoutingTable);
                fullRosterSync();
            }
        };
        final Thread t = new Thread(r, "Roster-Populating-Thread");
        t.setDaemon(true);
        t.start();
    }

    private Map<String, LanternRosterEntry> getRosterEntries(
        final Collection<RosterEntry> unordered) {
        final Map<String, LanternRosterEntry> entries =
            new ConcurrentSkipListMap<String, LanternRosterEntry>();
        for (final RosterEntry entry : unordered) {
            final LanternRosterEntry lre =
                new LanternRosterEntry(entry);
            if (LanternUtils.isNotJid(lre.getEmail())) {
                entries.put(lre.getEmail(), lre);
            }
        }
        return entries;
    }
    
    public LanternRosterEntry getRosterEntry(final String key) {
        return this.rosterEntries.get(key);
    }

    private void processPresence(final Presence presence, final boolean sync,
        final boolean updateIndex) {
        final String from = presence.getFrom();
        log.debug("Got presence: {}", presence.toXML());
        if (LanternXmppUtils.isLanternHub(from)) {
            log.info("Got Lantern hub presence");
        } else if (LanternXmppUtils.isLanternJid(from)) {
            Events.eventBus().post(new UpdatePresenceEvent(presence));

            // immediately add to kscope routing table and
            // send kscope ad to new roster entry
            final TrustGraphNodeId id = new BasicTrustGraphNodeId(from);
            log.debug("Adding {} to routing table.", from);
            this.kscopeRoutingTable.addNeighbor(id);

            
            // only advertise if we're in GET mode
            if(this.model.getSettings().getMode() == Settings.Mode.give) {
                sendKscope(presence, id);
            }
            onPresence(presence, sync, updateIndex);
        } else {
            onPresence(presence, sync, updateIndex);
        }
    }

    private void sendKscope(final Presence presence, final TrustGraphNodeId id) {
        //final TrustGraphNodeId tgnid = new BasicTrustGraphNodeId(
        //        model.getNodeId());

        if (!presence.isAvailable()) {
            log.info("Not sending kscope on unavailable: {}", presence.toXML());
            return;
        }
        final InetAddress address = 
            new PublicIpAddress().getPublicIpAddress();

        final String user = xmppHandler.getJid();
        final LanternKscopeAdvertisement ad;
        final MappedServerSocket ms = xmppHandler.getMappedServer();
        if (ms.isPortMapped()) {
            ad = new LanternKscopeAdvertisement(user, address, 
                xmppHandler.getMappedServer().getMappedPort(),
                xmppHandler.getMappedServer().getHostAddress()
            );
        } else {
            ad = new LanternKscopeAdvertisement(user, ms.getHostAddress());
        }

        final TrustGraphNode tgn = 
            new LanternTrustGraphNode(xmppHandler);
        // set ttl to max for now
        ad.setTtl(tgn.getMaxRouteLength());
        final String adPayload = JsonUtils.jsonify(ad);
        final BasicTrustGraphAdvertisement message =
            new BasicTrustGraphAdvertisement(id, adPayload, 
                LanternTrustGraphNode.DEFAULT_MIN_ROUTE_LENGTH
        );

        log.debug("Sending ad to newly online roster entry {}.", id);
        tgn.sendAdvertisement(message, id, ad.getTtl()); 
    }

    private void onPresence(final Presence pres, final boolean sync,
        final boolean updateIndex) {
        final String email = LanternXmppUtils.jidToEmail(pres.getFrom());
        final LanternRosterEntry entry = this.rosterEntries.get(email);
        if (entry != null) {
            entry.setAvailable(pres.isAvailable());
            entry.setStatusMessage(pres.getStatus());
            if (sync) {
                log.debug("Syncing roster from onPresence...");
                Events.syncRosterEntry(entry, entry.getIndex());
            }
        } else {
            // This may be someone we have subscribed to who we're just now
            // getting the presence for.
            log.debug("Adding non-roster presence: {}", email);
            addEntry(new LanternRosterEntry(pres),
                updateIndex);
        }

    }

    /**
     * Adds an entry, updating roster indexes. This should not be
     * called internally, as there should be more fine-grained control
     * over index building.
     *
     * NOTE: Public for testing.
     *
     * @param entry The entry to add.
     */
    public void addEntry(final LanternRosterEntry entry) {
        if (LanternUtils.isNotJid(entry.getEmail())) {
            log.info("Adding entry for {}", entry);
            putNewElement(entry, true);
        } else {
            log.debug("Not adding entry for {}", entry);
        }

        log.debug("Finished adding entry for {}", entry);

        //if (LanternUtils.isLanternJid(pres.getEmail()))
        //this.kscopeRoutingTable
    }

    /**
     * Adds an entry, optionally updating roster indexes.
     *
     * NOTE: Public for testing.
     *
     * @param entry The entry to add.
     * @param updateIndex Whether or not to update the index.
     */
    private void addEntry(final LanternRosterEntry entry,
        final boolean updateIndex) {
        if (LanternUtils.isNotJid(entry.getEmail())) {
            log.debug("Adding entry for {}", entry);
            putNewElement(entry, updateIndex);
        } else {
            log.debug("Not adding entry for {}", entry);
        }

        log.debug("Finished adding entry for {}", entry);
    }

    private void putNewElement(final LanternRosterEntry entry,
        final boolean updateIndex) {
        // Completely new roster entries are quite rare, so we do all the
        // work here to set the indexes for each entry.
        synchronized(this.rosterEntries) {
            final LanternRosterEntry elem =
                this.rosterEntries.put(entry.getEmail(), entry);

            // Only update the index if the element was actually added!
            if (elem == null) {
                if (updateIndex) {
                    updateIndex();
                }
            }
        }
    }

    private void updateIndex() {
        synchronized(this.rosterEntries) {
            final Set<LanternRosterEntry> sortedEntries =
                    new TreeSet<LanternRosterEntry>();
            sortedEntries.addAll(rosterEntries.values());
            int index = 0;
            for (final LanternRosterEntry cur : sortedEntries) {
                cur.setIndex(index);
                index++;
            }
        }
    }

    //@JsonUnwrapped
    public Collection<LanternRosterEntry> getEntries() {
        synchronized (this.rosterEntries) {
            return ImmutableSortedSet.copyOf(this.rosterEntries.values());
        }
    }

    public void setEntries(final Map<String, LanternRosterEntry> entries) {
        synchronized (this.rosterEntries) {
            this.rosterEntries.clear();
        }
        synchronized (entries) {
            final Collection<LanternRosterEntry> vals = entries.values();
            for (final LanternRosterEntry entry : vals) {
                putNewElement(entry, false);
            }
            updateIndex();
        }
    }

    public void addIncomingSubscriptionRequest(final Presence pres) {
        log.debug("Fetching vcard");
        this.model.getFriends().addPending(pres.getFrom());
        syncPending();
    }


    private void syncPending() {
        Events.syncAdd(SyncPath.SUBSCRIPTION_REQUESTS.getPath(), 
            this.model.getFriends().getPending());
    }
    
    public void removeIncomingSubscriptionRequest(final String from) {
        final String email = XmppUtils.jidToUser(from);
        this.model.getFriends().removePending(email);
        syncPending();
    }

    @Override
    public void entriesAdded(final Collection<String> entries) {
        log.debug("Adding {} entries to roster", entries.size());
        for (final String entry : entries) {
            addEntry(new LanternRosterEntry(entry), 
                false);
        }
        fullRosterSync();
    }

    private void fullRosterSync() {
        updateIndex();
        Events.syncRoster(this);
    }

    @Override
    public void entriesDeleted(final Collection<String> entries) {
        log.debug("Roster entries deleted: {}", entries);
        for (final String entry : entries) {
            final String email = LanternXmppUtils.jidToEmail(entry);
            synchronized (rosterEntries) {
                rosterEntries.remove(email);
            }
        }
        fullRosterSync();
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
            onPresence(pres, false, false);
        }
        fullRosterSync();
    }

    @Override
    public void presenceChanged(final Presence pres) {
        log.debug("Got presence changed event.");
        processPresence(pres, true, true);
    }


    public void reset() {
        this.model.getFriends().clear();
        synchronized (rosterEntries) {
            this.rosterEntries.clear();
        }
        this.kscopeRoutingTable.clear();
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
            log.debug("No matching roster entry!");
            return false;
        }
        final String subscriptionStatus = entry.getSubscriptionStatus();

        // If we're not still trying to subscribe or unsubscribe to this node,
        // then it is a legitimate entry.
        if (StringUtils.isBlank(subscriptionStatus)) {
            log.debug("Blank subscription status!");
            return true;
        }

        log.debug("Subscription status is: {}", subscriptionStatus);
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
