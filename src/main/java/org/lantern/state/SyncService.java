package org.lantern.state;

import java.util.Timer;
import java.util.TimerTask;

import org.cometd.annotation.Configure;
import org.cometd.annotation.Listener;
import org.cometd.annotation.Service;
import org.cometd.annotation.Session;
import org.cometd.bayeux.Channel;
import org.cometd.bayeux.Message;
import org.cometd.bayeux.server.ConfigurableServerChannel;
import org.cometd.bayeux.server.ServerSession;
import org.lantern.Events;
import org.lantern.LanternHub;
import org.lantern.event.ClosedBetaEvent;
import org.lantern.event.RosterStateChangedEvent;
import org.lantern.event.SyncEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
/*
import org.cometd.annotation.Configure;
import org.cometd.annotation.Listener;
import org.cometd.annotation.Service;
import org.cometd.annotation.Session;
*/

/**
 * Service for pushing updated Lantern state to the client.
 */
@Service("sync")
public class SyncService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Session
    private ServerSession session;
    
    private final SyncStrategy strategy;
    
    /**
     * Creates a new sync service.
     */
    public SyncService(final SyncStrategy strategy) {
        this.strategy = strategy;
        // Make sure the config class is added as a listener before this class.
        Events.register(this);
        
        final Timer timer = LanternHub.timer();
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                sync();
            }
        }, 3000, 4000);
    }
    
    @SuppressWarnings("unused")
    @Configure("/service/sync")
    private void configureSync(final ConfigurableServerChannel channel) {
        channel.setPersistent(true);
    }
    
    @Listener(Channel.META_CONNECT)
    public void metaConnect(final ServerSession remote, final Message connect) {
        // Make sure we give clients the most recent data whenever they connect.
        log.debug("Got connection from client, calling sync");
        
        final Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                log.info("Syncing with frontend...");
                sync();
            }
            
        }, "CometD-Sync-OnConnect-Thread");
        t.setDaemon(true);
        t.start();
    }

    @Listener("/service/sync")
    public void processSync(final ServerSession remote, final Message message) {
        log.debug("JSON: {}", message.getJSON());
        log.debug("DATA: {}", message.getData());
        log.debug("DATA CLASS: {}", message.getData().getClass());
        
        /*
        final String fullJson = message.getJSON();
        final String json = StringUtils.substringBetween(fullJson, "\"data\":", ",\"channel\":");
        final Map<String, Object> update = message.getDataAsMap();
        log.debug("MAP: {}", update);
        */

        log.debug("Pushing updated config to browser...");
        sync();
    }
    
    @Subscribe
    public void onSync(final SyncEvent syncEvent) {
        log.debug("Got sync event");
        // We want to force a sync here regardless of whether or not we've 
        // recently synced.
        sync(true, syncEvent.getChannel());
    }

    @Subscribe 
    public void onRosterStateChanged(final RosterStateChangedEvent rsce) {
        log.debug("Roster changed...");
        rosterSync();
    }
    
    @Subscribe 
    public void closedBeta(final ClosedBetaEvent betaEvent) {
        sync(true);
    }
    
    private void rosterSync() {
        sync(false, SyncChannel.roster);
    }
    
    private void sync(final boolean force) {
        sync(force, SyncChannel.model);
        //sync(force, SyncChannel.transfers);
    }
    
    private void sync() {
        sync(false);
    }
    
    private void sync(final boolean force, final SyncChannel channel) {
        log.debug("In sync method");
        this.strategy.sync(force, channel, this.session);
    }

    public void publishSync(final String path, final Object value) {
        this.strategy.sync(true, this.session, path, value);
    }
}
