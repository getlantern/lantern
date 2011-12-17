package org.lantern;

import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.atomic.AtomicBoolean;

import org.cometd.bayeux.Message;
import org.cometd.bayeux.client.ClientSessionChannel;
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
        
        final Timer timer = LanternHub.timer();
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                log.info("Updating");
                sync();
            }
        }, 3000, 4000);
    }

    @Listener("/service/sync")
    public void processSync(final ServerSession remote, final Message message) {
        //final Map<String, Object> input = message.getDataAsMap();
        log.info("Pushing updated config to browser...");
        //final String output = LanternHub.config().configAsJson();
        //log.info("Config is: {}", output);
        //remote.deliver(session, "/sync", LanternHub.config().config(), null);
        sync();
    }

    @Override
    public void onUpdate(final LanternUpdate lanternUpdate) {
        log.info("Got update");
        sync();
    }

    @Override
    public void onPresence(final String address, final Presence presence) {
        log.info("Got presence");
        sync();
    }

    @Override
    public void removePresence(final String address) {
        this.updated.set(true);
        sync();
    }
    
    private void sync() {
        log.info("Syncing with channel...");
        if (session == null) {
            log.info("No session...not syncing");
            return;
        }
        final ClientSessionChannel channel = 
            session.getLocalSession().getChannel("/sync");
        channel.publish(LanternHub.config().config());
    }
}
