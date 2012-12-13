package org.lantern.event;

import java.util.concurrent.Executors;

import org.lantern.LanternRosterEntry;
import org.lantern.Roster;
import org.lantern.state.Modal;
import org.lantern.state.Model;
import org.lantern.state.SyncPath;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.AsyncEventBus;
import com.google.common.eventbus.EventBus;
import com.google.common.util.concurrent.ThreadFactoryBuilder;

public class Events {

    private static final Logger LOG = LoggerFactory.getLogger(Events.class);
    
    private static final EventBus eventBus = new EventBus();

    private static final AsyncEventBus asyncEventBus =
        new AsyncEventBus("Async-Event-Bus", Executors.newCachedThreadPool(
            new ThreadFactoryBuilder().setDaemon(true).setNameFormat(
                "Async-Event-Thread-%d").build()));

    public static void register(final Object toRegister) {
        asyncEventBus.register(toRegister);
        eventBus.register(toRegister);
    }
    
    
    public static EventBus eventBus() {
        return eventBus;
    }

    public static AsyncEventBus asyncEventBus() {
        return asyncEventBus;
    }

    /**
     * Convenience method for syncing a new modal both with the state model
     * and with the frontend.
     * 
     * @param model The state model.
     * @param modal The modal to set.
     */
    public static void syncModal(final Model model, final Modal modal) {
        model.setModal(modal);
        syncModal(model);
    }

    /**
     * Convenience method for syncing the current modal with the frontend.
     * 
     * @param model The state model.
     */
    public static void syncModal(final Model model) {
        Events.asyncEventBus().post(new SyncEvent(SyncPath.MODAL, model.getModal()));
    }
    
    /**
     * Convenience method for syncing the current modal with the frontend.
     */
    public static void syncRoster(final Roster roster) {
        // This is done synchronously because we need the roster array on the
        // frontend to be in sync with the backend in order to index into it 
        // on roster updates.
        Events.eventBus().post(new SyncEvent(SyncPath.ROSTER, roster.getEntries()));
    }
    

    public static void syncRosterEntry(final LanternRosterEntry entry, final int index) {
        final String path = SyncPath.ROSTER.getPath()+"."+index;
        LOG.debug("Syncing roster entry at path {} with entry {}", path, entry);
        Events.eventBus().post(new SyncEvent(path, entry));
    }


    public static void sync(final SyncPath path, final Object value) {
        Events.asyncEventBus().post(new SyncEvent(path, value));
    }


    public static void syncModel(final Model model) {
        sync(SyncPath.ALL, model);
    }


    public static void syncNInvites(final Integer ninvites) {
        sync(SyncPath.NINVITES, ninvites);
    }
}
