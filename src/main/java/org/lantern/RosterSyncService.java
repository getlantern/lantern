package org.lantern;

import java.util.Timer;
import java.util.TimerTask;

import org.cometd.bayeux.Channel;
import org.cometd.bayeux.Message;
import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.ConfigurableServerChannel;
import org.cometd.bayeux.server.ServerSession;
import org.cometd.java.annotation.Configure;
import org.cometd.java.annotation.Listener;
import org.cometd.java.annotation.Service;
import org.cometd.java.annotation.Session;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * Service for pushing updated Lantern roster state to the client.
 */
@Service("rostersync")
public class RosterSyncService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Session
    private ServerSession session;
    
    /**
     * Creates a new roster sync service.
     */
    public RosterSyncService() {
        // Make sure the config class is added as a listener before this class.
        LanternHub.register(this);
    }
    
    @SuppressWarnings("unused")
    @Configure("/service/rostersync")
    private void configureSync(final ConfigurableServerChannel channel) {
        channel.setPersistent(true);
    }
    
    @Listener(Channel.META_CONNECT)
    public void metaConnect(final ServerSession remote, final Message connect) {
        // Make sure we give clients the most recent data whenever they connect.
        log.debug("Got connection from client, calling sync");
        sync();
    }

    @Listener("/service/rostersync")
    public void processSync(final ServerSession remote, final Message message) {
        log.debug("JSON: {}", message.getJSON());
        log.debug("DATA: {}", message.getData());
        log.debug("DATA CLASS: {}", message.getData().getClass());
        log.debug("Pushing updated config to browser...");
        sync();
    }
    
    @Subscribe 
    public void onRosterStateChanged(final RosterStateChangedEvent rsce) {
        log.debug("Roster changed...");
        sync();
    }
    
    private void sync() {
        log.debug("In sync method");
        if (session == null) {
            log.debug("No session...not syncing");
            return;
        }
        
        final ClientSessionChannel channel = 
            session.getLocalSession().getChannel("/sync");
        
        if (channel != null) {
            final Roster roster = LanternHub.xmppHandler().getRoster();
            channel.publish(roster);
            log.debug("Sync performed");
        }
    }
}
