package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.net.URI;
import java.util.Arrays;
import java.util.Collection;
import java.util.Map;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.atomic.AtomicReference;

import org.jivesoftware.smack.RosterEntry;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.Presence.Type;
import org.junit.Ignore;
import org.junit.Test;
import org.kaleidoscope.BasicRandomRoutingTable;
import org.kaleidoscope.RandomRoutingTable;
import org.lantern.endpoints.FriendApi;
import org.lantern.event.Events;
import org.lantern.event.SyncEvent;
import org.lantern.kscope.ReceivedKScopeAd;
import org.lantern.network.NetworkTracker;
import org.lantern.oauth.OauthUtils;
import org.lantern.oauth.RefreshToken;
import org.lantern.state.DefaultFriendsHandler;
import org.lantern.state.FriendsHandler;
import org.lantern.state.Model;
import org.lantern.util.HttpClientFactory;

import com.google.common.eventbus.Subscribe;

@Ignore
public class RosterTest {

    private final AtomicReference<String> path = new AtomicReference<String>();

    @Test
    public void testIndexedSync() throws Exception {
        Events.register(this);
        final RandomRoutingTable routingTable = new BasicRandomRoutingTable();
        final Model model = new Model();
        final HttpClientFactory httpClientFactory = TestingUtils.newHttClientFactory();
        final OauthUtils oauth = 
                new OauthUtils(httpClientFactory, model, new RefreshToken(model));
        final FriendApi api = new FriendApi(oauth, model);
        final XmppHandler xmppHandler = TestingUtils.newXmppHandler();
        final NetworkTracker<String, URI, ReceivedKScopeAd> networkTracker = new NetworkTracker<String, URI, ReceivedKScopeAd>();
        final FriendsHandler friendHandler = 
                new DefaultFriendsHandler(model, api, xmppHandler, null, networkTracker, new Messages(new Model()));
        final Roster roster =
            new Roster(routingTable, model, new TestCensored(), friendHandler);

        final String url = "http://127.0.0.1:2174/photo/";
        final Map<String, LanternRosterEntry> entries = 
            new ConcurrentSkipListMap<String, LanternRosterEntry>();
        
        final SortedSet<LanternRosterEntry> sortedSet = 
                new TreeSet<LanternRosterEntry>();
        for (int i = 0; i < 1000; i++) {
            buildEntry(i, url, roster, entries, sortedSet);
        }
        roster.setEntries(entries);
        
        Collection<LanternRosterEntry> rost = roster.getEntries();
        final LanternRosterEntry first = rost.iterator().next();
        
        assertTrue(first == sortedSet.first());
        
        int index = 0;
        for (final LanternRosterEntry entry : rost) {
            final Presence pres = new Presence(Type.available);
            pres.setStatus("still-testing-this-baby");
            pres.setFrom(entry.getUser());

            roster.presenceChanged(pres);
            
            // The presence notification in the sync event (see below) will have
            // updated our path variable here.
            assertEquals("roster/"+index, path.get());
            
            assertEquals(index, entry.getIndex());
            index++;
        }
        
        // Now add a new entry and make sure all the indexes are
        // updated.
        RosterEntry rosterEntry = makeMockRosterEntry("totally different email key");
        final LanternRosterEntry lre =
            new LanternRosterEntry(rosterEntry);
        roster.addEntry(lre, true);
        
        
        path.set("reset");
        int oldSize = rost.size();
        rost = roster.getEntries();
        assertEquals(oldSize+1, rost.size());
        index = 0;
        for (final LanternRosterEntry entry : rost) {
            final Presence pres = new Presence(Type.available);
            pres.setStatus("testing-this-baby-some-more");
            pres.setFrom(entry.getEmail());
            
            roster.presenceChanged(pres);
            // The presence notification in the sync event (see below) will have
            // updated our path variable here.
            assertEquals("roster/"+index, path.get());
            
            assertEquals(index, entry.getIndex());
            index++;
        }
        
        roster.entriesDeleted(Arrays.asList(lre.getEmail()));

        path.set("reset");
        oldSize = rost.size();
        rost = roster.getEntries();
        assertEquals(oldSize-1, rost.size());
        index = 0;
        for (final LanternRosterEntry entry : rost) {
            final Presence pres = new Presence(Type.available);
            pres.setStatus("testing-this-baby-some-more");
            pres.setFrom(entry.getEmail());
            
            roster.presenceChanged(pres);
            // The presence notification in the sync event (see below) will have
            // updated our path variable here.
            assertEquals("roster/"+index, path.get());
            
            assertEquals(index, entry.getIndex());
            index++;
        }
    }

    private LanternRosterEntry buildEntry(final int chronologicalIndex, 
        final String url,
        final Roster roster, final Map<String, LanternRosterEntry> entries, 
        final SortedSet<LanternRosterEntry> sorted) {
        RosterEntry mockRosterEntry = makeMockRosterEntry("entry"+chronologicalIndex);
        final LanternRosterEntry lre =
            new LanternRosterEntry(mockRosterEntry);

        entries.put(lre.getUser(), lre);
        sorted.add(lre);
        return lre;
    }

    private RosterEntry makeMockRosterEntry(String email) {
        RosterEntry entry = mock(RosterEntry.class);

        when(entry.getUser()).thenReturn(email);
        when(entry.getName()).thenReturn(email);

        return entry;
    }

    @Subscribe
    public void onSync(final SyncEvent sync) {
        final String syncPath = sync.getPath();
        // We could get other random sync events, like for countries -- just
        // ignore them.
        if (syncPath.startsWith("roster")) {
            this.path.set(syncPath);
        }
    }
}
