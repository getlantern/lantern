package org.lantern;

import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import org.cometd.bayeux.Message;
import org.cometd.bayeux.server.ServerSession;
import org.cometd.java.annotation.Listener;
import org.cometd.java.annotation.Service;
import org.cometd.java.annotation.Session;
import org.jivesoftware.smack.packet.Presence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Service for pushing updated Lantern state to the client.
 */
@Service("sync")
public class SyncService implements PresenceListener, LanternUpdateListener {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final AtomicBoolean updated = new AtomicBoolean(false);
    
    @Session
    private ServerSession session;
    
    /**
     * Creates a new sync service.
     */
    public SyncService() {
        // Make sure the config class is added as a listener before this class.
        LanternHub.config();
        LanternHub.notifier().addPresenceListener(this);
        LanternHub.notifier().addUpdateListener(this);
    }

    @Listener("/service/sync")
    public void processSync(final ServerSession remote, final Message message) {
        final Map<String, Object> input = message.getDataAsMap();
        log.info("Pushing updated config to browser...");
        final String output = LanternHub.config().configAsJson();
        log.info("Config is: {}", output);
        remote.deliver(session, "/sync", LanternHub.config().config(), null);
    }

    @Override
    public void onUpdate(final LanternUpdate lanternUpdate) {
        //session.getLocalSession().
        //this.updated.set(true);
    }

    @Override
    public void onPresence(final String address, Presence presence) {
        this.updated.set(true);
    }

    @Override
    public void removePresence(final String address) {
        this.updated.set(true);
    }
}
