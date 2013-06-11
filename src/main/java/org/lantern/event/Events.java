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
                "Lantern-Async-Event-Thread-%d").build()));
    
    private static final AsyncEventBus inOrderAsyncEventBus =
            new AsyncEventBus("In-Order-Async-Event-Bus", 
                Executors.newSingleThreadExecutor(
                new ThreadFactoryBuilder().setDaemon(true).setNameFormat(
                    "Lantern-In-Order-Async-Event-Thread-%d").build()));

    public static void register(final Object toRegister) {
        asyncEventBus.register(toRegister);
        eventBus.register(toRegister);
        inOrderAsyncEventBus.register(toRegister);
    }


    public static EventBus eventBus() {
        return eventBus;
    }

    public static AsyncEventBus asyncEventBus() {
        return asyncEventBus;
    }
    
    public static AsyncEventBus inOrderAsyncEventBus() {
        return inOrderAsyncEventBus;
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
        final String path = SyncPath.ROSTER.getPath()+"/"+index;
        LOG.debug("Syncing roster entry at path {} with entry {}", path, entry);
        Events.eventBus().post(new SyncEvent(SyncType.REPLACE, path, entry));
    }


    public static void sync(final SyncPath path, final Object value) {
        Events.asyncEventBus().post(new SyncEvent(path, value));
    }

    /**
     * Syncs the entire state document with the frontend. This should happen
     * rarely and typically only when so many parts of the model have changed
     * that it makes sense to sync the whole thing. The model gets very large,
     * however, so this is to be avoided.
     * 
     * @param model The model to sync.
     */
    public static void syncModel(final Model model) {
        LOG.info("SYNCING ENTIRE MODEL. ARE YOU SURE THIS IS NECESSARY?");
        sync(SyncPath.ALL, model);
    }

    public static void syncAdd(String path, Object value) {
        Events.asyncEventBus().post(new SyncEvent(SyncType.ADD, path, value));
    }

    public static void syncConnectingStatus(final String status) {
        Events.eventBus().post(
            new SyncEvent(SyncType.ADD, SyncPath.CONNECTING_STATUS, status));
    }
}
