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
import org.lantern.LanternService;
import org.lantern.event.ClosedBetaEvent;
import org.lantern.event.Events;
import org.lantern.event.SyncEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Service for pushing updated Lantern state to the client.
 */
@Service("sync")
@Singleton
public class SyncService implements LanternService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Session
    private ServerSession session;
    
    private final SyncStrategy strategy;

    private final Model model;

    private final Timer timer;

    /**
     * Creates a new sync service.
     * 
     * @param strategy The strategy to use for syncing
     * @param model The model to use.
     */
    @Inject
    public SyncService(final SyncStrategy strategy, 
        final Model model, final Timer timer) {
        this.strategy = strategy;
        this.model = model;
        this.timer = timer;
        // Make sure the config class is added as a listener before this class.
        Events.register(this);
    }
    

    @Override
    public void start() throws Exception {
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                //sync();
            }
        }, 3000, 4000);
    }

    @Override
    public void stop() {
        this.timer.cancel();
    }
    
    @SuppressWarnings("unused")
    @Configure("/service/sync")
    private void configureSync(final ConfigurableServerChannel channel) {
        channel.setPersistent(true);
    }
    
    //@Listener(Channel.META_CONNECT)
    @Listener(Channel.META_SUBSCRIBE)
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
        //sync(true, syncEvent.getChannel());
        publishSync(syncEvent.getPath(), syncEvent.getValue());
    }
    
    @Subscribe 
    public void closedBeta(final ClosedBetaEvent betaEvent) {
        sync(true);
    }
    
    private void sync() {
        sync(false);
    }
    
    private void sync(final boolean force) {
        log.debug("In sync method");
        //this.strategy.sync(force, channel, this.session);
        
        this.strategy.sync(force, this.session, SyncPath.ALL, this.model);
    }

    public void publishSync(final SyncPath path, final Object value) {
        this.strategy.sync(true, this.session, path, value);
    }
}
