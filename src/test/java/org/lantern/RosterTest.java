package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.util.Arrays;
import java.util.Collection;
import java.util.Map;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.lang.math.RandomUtils;
import org.jivesoftware.smack.packet.Presence;
import org.jivesoftware.smack.packet.Presence.Type;
import org.junit.Test;
import org.lantern.event.Events;
import org.lantern.event.SyncEvent;
import org.lantern.state.Model;
import org.lantern.XmppHandler;

import org.kaleidoscope.RandomRoutingTable;
import org.kaleidoscope.BasicRandomRoutingTable;

import com.google.common.eventbus.Subscribe;

public class RosterTest {

    private final AtomicReference<String> path = new AtomicReference<String>();
    
    @Test
    public void testIndexedSync() throws Exception {
        Events.register(this);
        TestUtils.load(true);
        RandomRoutingTable routingTable = new BasicRandomRoutingTable();
        XmppHandler xmppHandler = TestUtils.getXmppHandler();
        Model model = TestUtils.getModel();
        final Roster roster = new Roster(routingTable, xmppHandler, model);
        
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
            pres.setFrom(entry.getEmail());
            
            roster.presenceChanged(pres);
            
            // The presence notification in the sync event (see below) will have
            // updated our path variable here.
            assertEquals("roster."+index, path.get());
            
            assertEquals(index, entry.getIndex());
            index++;
        }
        
        // Now add a new entry and make sure all the indexes are
        // updated.
        final LanternRosterEntry lre = 
            new LanternRosterEntry("totally different email key");
        roster.addEntry(lre);
        
        
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
            assertEquals("roster."+index, path.get());
            
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
            assertEquals("roster."+index, path.get());
            
            assertEquals(index, entry.getIndex());
            index++;
        }
    }

    private LanternRosterEntry buildEntry(final int chronologicalIndex, 
        final String url,
        final Roster roster, final Map<String, LanternRosterEntry> entries, 
        final SortedSet<LanternRosterEntry> sorted) {
        final LanternRosterEntry lre = 
            new LanternRosterEntry("entry"+chronologicalIndex);

        entries.put(lre.getEmail(), lre);
        sorted.add(lre);
        return lre;
    }

    @Subscribe
    public void onSync(final SyncEvent sync) {
        this.path.set(sync.getPath());
    }
}
