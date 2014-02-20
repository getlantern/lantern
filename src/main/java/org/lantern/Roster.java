package org.lantern;

import java.net.InetAddress;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.lang3.StringUtils;
import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.RosterListener;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.RosterPacket.ItemStatus;
import org.kaleidoscope.BasicTrustGraphAdvertisement;
import org.kaleidoscope.BasicTrustGraphNodeId;
import org.kaleidoscope.RandomRoutingTable;
import org.kaleidoscope.TrustGraphNode;
import org.kaleidoscope.TrustGraphNodeId;
import org.lantern.annotation.Keep;
import org.lantern.event.Events;
import org.lantern.event.ResetEvent;
import org.lantern.event.UpdatePresenceEvent;
import org.lantern.kscope.LanternKscopeAdvertisement;
import org.lantern.kscope.LanternTrustGraphNode;
import org.lantern.state.Friend;
import org.lantern.state.FriendsHandler;
import org.lantern.state.Model;
import org.lantern.util.PublicIpAddress;
import org.lantern.util.Threads;
import org.lastbamboo.common.ice.MappedServerSocket;
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
@Keep
public class Roster implements RosterListener {

    private final Logger log = LoggerFactory.getLogger(getClass());

    /**
     * Wrap this because it get set by multiple threads -- both this one
     * now and another when we load the real roster.
     */
    private final AtomicReference<Map<String, LanternRosterEntry>> rosterEntries =
        new AtomicReference<Map<String, LanternRosterEntry>>(
            new ConcurrentSkipListMap<String, LanternRosterEntry>());

    private final RandomRoutingTable kscopeRoutingTable;
    private final Model model;

    private org.jivesoftware.smack.Roster smackRoster;

    private XmppHandler xmppHandler;

    private final Censored censored;

    private final FriendsHandler friendsHandler;
    
    private final ExecutorService rosterExecutor = 
            Threads.newSingleThreadExecutor("Unified-Roster-Thread");

    /**
     * Creates a new roster.
     */
    @Inject
    public Roster(final RandomRoutingTable routingTable, 
            final Model model, final Censored censored, 
            final FriendsHandler friendsHandler) {
        this.kscopeRoutingTable = routingTable;
        this.model = model;
        this.censored = censored;
        this.friendsHandler = friendsHandler;
        model.setRoster(this);
        Events.register(this);
    }

    public void onRoster(final XmppHandler xmpp) {
        this.xmppHandler = xmpp;
        log.info("Got logged in event");
        // Threaded to avoid this holding up setting the logged-in state in
        // the UI.
        final XMPPConnection conn = xmpp.getP2PClient().getXmppConnection();
        final org.jivesoftware.smack.Roster ros = conn.getRoster();
        this.smackRoster = ros;
        
        final Callable<Roster> r = new Callable<Roster>() {

            @Override
            public Roster call() throws Exception {
                ros.setSubscriptionMode(
                    org.jivesoftware.smack.Roster.SubscriptionMode.manual);
                ros.addRosterListener(Roster.this);
                final Collection<RosterEntry> unordered = ros.getEntries();
                log.debug("Got roster entries!!");

                final Set<String> alreadyOnRoster = new HashSet<String>(unordered.size());
                for (final RosterEntry entry : unordered) {
                    log.debug("START {} ***********************", entry.getUser());
                    final LanternRosterEntry lre = new LanternRosterEntry(entry);
                    addEntry(lre, false);
                    processRosterEntryPresences(entry);
                    final String email = lre.getEmail();
                    alreadyOnRoster.add(email);
                    log.debug("STATUS OF {}: {}", entry.getUser(), entry.getStatus());
                    if (entry.getStatus() == ItemStatus.SUBSCRIPTION_PENDING) {
                        if (friendsHandler.isFriend(email)) {
                            xmppHandler.subscribed(email);
                        } else {
                            log.debug("Not sending subscribed message to "
                                    + "non-friend: {}", email);
                        }
                    }
                    log.debug("END {} ***********************\n\n", entry.getUser());
                }

                for (Friend friend : friendsHandler.getFriends()) {
                    if (!alreadyOnRoster.contains(friend.getEmail())) {
                        //we have a friend who is not yet on our roster.
                        xmppHandler.subscribe(friend.getEmail());
                    }
                }
                
                sendKscopeAdToAllPeers();
                log.debug("Finished populating roster");
                log.info("kscope is: {}", kscopeRoutingTable);
                fullRosterSync();
                
                return Roster.this;
            }
        };
        
        rosterExecutor.submit(r);
    }

    public LanternRosterEntry getRosterEntry(final String key) {
        try {
            return this.rosterEntries.get().get(LanternXmppUtils.jidToEmail(key));
        } catch (EmailAddressUtils.NormalizationException e) {
            throw new RuntimeException(e);
        }
    }

    public Collection<LanternRosterEntry> getEntries() {
        synchronized (this.rosterEntries) {
            // Note these are sorted loosely according to how frequently we
            // communicate with them -- see LanternRosterEntry compareTo.
            final ImmutableSortedSet<LanternRosterEntry> entries = 
                    ImmutableSortedSet.copyOf(this.rosterEntries.get().values());
            return entries;
        }
    }

    public void setEntries(final Map<String, LanternRosterEntry> entries) {
        
        rosterExecutor.execute(new Runnable() {
            @Override
            public void run() {
                synchronized (rosterEntries) {
                    rosterEntries.get().clear();
                }
                synchronized (entries) {
                    final Collection<LanternRosterEntry> vals = entries.values();
                    for (final LanternRosterEntry entry : vals) {
                        addEntry(entry, false);
                    }
                    updateIndex();
                }
            }
        });
    }

    @Override
    public void entriesAdded(final Collection<String> addresses) {
        log.debug("Adding {} entries to roster", addresses.size());
        rosterExecutor.execute(new Runnable() {
            @Override
            public void run() {
                for (final String address : addresses) {
                    final RosterEntry entry = smackRoster.getEntry(address);
                    if (entry == null) {
                        log.warn("Unexpectedly, an entry that we have added to the" +
                                  "roster isn't in Smack's roster.  Skipping it");
                        continue;
                    }
                    addEntry(new LanternRosterEntry(entry), false);
                    friendsHandler.updateName(address, entry.getName());
                    processRosterEntryPresences(entry);
                }
                fullRosterSync();
                friendsHandler.syncFriends();
            }
        });
    }

    @Override
    public void entriesDeleted(final Collection<String> entries) {
        rosterExecutor.execute(new Runnable() {
            @Override
            public void run() {
                log.debug("Roster entries deleted: {}", entries);
                for (final String entry : entries) {
                    try {
                        final String email = LanternXmppUtils.jidToEmail(entry);
                        synchronized (rosterEntries) {
                            rosterEntries.get().remove(email);
                        }
                    } catch (EmailAddressUtils.NormalizationException e) {
                        throw new RuntimeException(e);
                    }
                }
                fullRosterSync();
            }
        });
    }

    @Override
    public void entriesUpdated(final Collection<String> entries) {
        rosterExecutor.execute(new Runnable() {
            @Override
            public void run() {
                log.debug("Entries updated: {} for roster: {}", entries, this);
                if (smackRoster == null) {
                    log.error("No roster yet?");
                    return;
                }
                for (final String entry : entries) {
                    final Presence pres = smackRoster.getPresence(entry);
                    onPresence(pres, false, false);
                }
                fullRosterSync();
            }
        });
    }

    @Override
    public void presenceChanged(final Presence pres) {
        log.debug("Got presence changed event.");
        rosterExecutor.execute(new Runnable() {
            @Override
            public void run() {
                processPresence(pres, true, true);
                log.debug("Processed presence changed...");
            }
        });
    }

    public void reset() {
        synchronized (rosterEntries) {
            this.rosterEntries.get().clear();
        }
        this.kscopeRoutingTable.clear();
    }

    public boolean autoAcceptSubscription(final String from) {
        final LanternRosterEntry entry = getRosterEntry(from);
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
    

    public RosterEntry getEntry(String email) {
        if (this.smackRoster != null) {
            return smackRoster.getEntry(email);
        }
        return null;
    }
    

    private void processPresence(final Presence presence, final boolean sync,
        final boolean updateIndex) {
        final String from = presence.getFrom();
        log.debug("Got presence: {}", presence.toXML());
        if (LanternUtils.isLanternHub(from)) {
            log.debug("Got Lantern hub presence");
        } else if (LanternXmppUtils.isLanternJid(from)) {
            if (friendsHandler.isFriend(from)) {
                Events.eventBus().post(new UpdatePresenceEvent(presence));
                if (presence.isAvailable()) {
                    sendKscope(from);
                }
                onPresence(presence, sync, updateIndex);
            } else {
                log.debug("Got presence from non-friend: {}", from);
            }
        } else {
            onPresence(presence, sync, updateIndex);
        }
    }
    
    private void sendKscopeAdToAllPeers() {
        log.debug("Sending KScope ads to all peers");
        final Collection<LanternRosterEntry> entries = getEntries();
        for (final LanternRosterEntry lre : entries) {
            if (!lre.isAvailable()) {
                log.debug("Entry not listed as available {}", lre.getUser());
            }
            if (friendsHandler.isFriend(lre.getEmail())) {
                sendKscope(lre.getUser());
            } else {
                log.debug("Not sending kscope ad to non-friend: {}", 
                        lre.getEmail());
            }
        }
    }

    private void sendKscope(final String to) {
        if (!LanternXmppUtils.isLanternJid(to)) {
            log.debug("Not sending kscope add to non Lantern entry");
            return;
        }
        if (censored.isCensored()) {
            log.debug("Not sending kscope advertisement in censored mode");
            return;
        }
        
        if (xmppHandler == null) {
            log.warn("Null xmppHandler?");
            return;
        }
        // immediately add to kscope routing table and
        // send kscope ad to new roster entry
        final TrustGraphNodeId id = new BasicTrustGraphNodeId(to);
        log.debug("Adding {} to routing table.", to);
        this.kscopeRoutingTable.addNeighbor(id);
        final InetAddress address = 
            new PublicIpAddress().getPublicIpAddress();

        final String user = xmppHandler.getJid();
        final LanternKscopeAdvertisement ad;
        final MappedServerSocket ms = xmppHandler.getMappedServer();
        String[] proxiedSites = Whitelist.getDefaultWhitelistedSites();
        if (ms.isPortMapped()) {
            ad = new LanternKscopeAdvertisement(user, address, 
                ms.getMappedPort(), ms.getHostAddress(), proxiedSites
            );
        } else {
            ad = new LanternKscopeAdvertisement(user, address,
                    ms.getHostAddress(), proxiedSites);
        }

        final TrustGraphNode tgn = new LanternTrustGraphNode();
        // set ttl to max for now
        ad.setTtl(tgn.getMaxRouteLength());
        final String adPayload = JsonUtils.jsonify(ad);
        final BasicTrustGraphAdvertisement message =
            new BasicTrustGraphAdvertisement(id, adPayload,
                LanternTrustGraphNode.DEFAULT_MIN_ROUTE_LENGTH
        );

        final int ttl;
        if (!LanternUtils.isFallbackProxy()) {
            log.debug("Sending ad to newly online roster entry {}.", id);
            ttl = ad.getTtl();
        } else {
            log.debug("Reducing TTL for fallback proxies");
            ttl = 0;
        }
        tgn.sendAdvertisement(message, id, ttl);
    }

    private void onPresence(final Presence pres, final boolean sync,
        final boolean updateIndex) {
        final LanternRosterEntry entry = getRosterEntry(pres.getFrom());
        if (entry != null) {
            entry.setAvailable(pres.isAvailable());
            entry.setStatusMessage(pres.getStatus());
            if (sync) {
                log.debug("Syncing roster from onPresence...");
                Events.syncRosterEntry(entry, entry.getIndex());
            }
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
    public void addEntry(final LanternRosterEntry entry,
        final boolean updateIndex) {
        if (LanternUtils.isAnonymizedGoogleTalkAddress(entry.getEmail())) {
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
            try {
                final LanternRosterEntry elem =
                    this.rosterEntries.get().put(
                            EmailAddressUtils.normalizedEmail(entry.getEmail()),
                            entry);
                // Only update the index if the element was actually added!
                if (elem == null) {
                    if (updateIndex) {
                        updateIndex();
                    }
                }
            } catch (EmailAddressUtils.NormalizationException e) {
                throw new RuntimeException(e);
            }

        }
    }
    

    private void processRosterEntryPresences(final RosterEntry entry) {
        final Iterator<Presence> presences =
            this.smackRoster.getPresences(entry.getUser());
        while (presences.hasNext()) {
            final Presence p = presences.next();
            processPresence(p, false, false);
        }
    }

    private void updateIndex() {
        synchronized(this.rosterEntries) {
            final Set<LanternRosterEntry> sortedEntries =
                    new TreeSet<LanternRosterEntry>();
            sortedEntries.addAll(rosterEntries.get().values());
            int index = 0;
            for (final LanternRosterEntry cur : sortedEntries) {
                cur.setIndex(index);
                index++;
            }
        }
    }

    private void fullRosterSync() {
        updateIndex();
        Events.syncRoster(this);
    }
}
