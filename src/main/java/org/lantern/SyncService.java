package org.lantern;

import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import org.apache.commons.lang.StringUtils;
import org.cometd.bayeux.Message;
import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.ConfigurableServerChannel;
import org.cometd.bayeux.server.ServerChannel.ServerChannelListener;
import org.cometd.bayeux.server.ServerSession;
import org.cometd.bayeux.server.ServerSession.ServerSessionListener;
import org.cometd.java.annotation.Configure;
import org.cometd.java.annotation.Listener;
import org.cometd.java.annotation.Service;
import org.cometd.java.annotation.Session;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * Service for pushing updated Lantern state to the client.
 */
@Service("sync")
public class SyncService {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Session
    private ServerSession session;
    
    private volatile long lastUpdateTime = System.currentTimeMillis();
    
    /**
     * Creates a new sync service.
     */
    public SyncService() {
        // Make sure the config class is added as a listener before this class.
        LanternHub.eventBus().register(this);
        LanternHub.asyncEventBus().register(this);
        
        final Timer timer = LanternHub.timer();
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                sync();
            }
        }, 3000, 4000);
        
        Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

            @Override
            public void run() {
                log.info("Notifying frontend backend is no longer running");
                LanternHub.systemInfo().setBackendRunning(false);
                sync();
            }
            
        }, "Backend-Not-Running-Thread"));
    }
    
    @SuppressWarnings("unused")
    @Configure("/service/sync")
    private void configureSync(final ConfigurableServerChannel channel) {
        channel.setPersistent(true);
    }

    @Listener("/service/sync")
    public void processSync(final ServerSession remote, final Message message) {
        log.info("JSON: {}", message.getJSON());
        log.info("DATA: {}", message.getData());
        log.info("DATA CLASS: {}", message.getData().getClass());
        
        /*
        final String fullJson = message.getJSON();
        final String json = StringUtils.substringBetween(fullJson, "\"data\":", ",\"channel\":");
        final Map<String, Object> update = message.getDataAsMap();
        log.info("MAP: {}", update);
        */

        log.info("Pushing updated config to browser...");
        sync();
    }
    
    @Subscribe
    public void onUpdate(final UpdateEvent updateEvent) {
        log.info("Got update");
        sync();
    }
    
    @Subscribe
    public void onSync(final SyncEvent syncEvent) {
        log.info("Got sync event");
        sync();
    }
    
    @Subscribe
    public void onPresence(final AddPresenceEvent event) {
        log.info("Got presence");
        sync();
    }

    @Subscribe
    public void removePresence(final RemovePresenceEvent event) {
        log.info("Presence removed...");
        sync();
    }
    
    @Subscribe 
    public void onRosterStateChanged(final RosterStateChangedEvent rsce) {
        log.info("Roster changed...");
        sync();
    }
    
    @Subscribe 
    public void onConnectivityStateChanged(
        final ConnectivityStatusChangeEvent csce) {
        log.info("Got connectivity change");
        sync();
    }
    
    private void sync() {
        log.info("Syncing with channel...");
        if (session == null) {
            log.info("No session...not syncing");
            return;
        }
        final long elapsed = System.currentTimeMillis() - lastUpdateTime;
        if (elapsed < 100) {
            log.info("Not pushing more than 10 times a second...{} ms elapsed", 
                elapsed);
            return;
        }
        final ClientSessionChannel channel = 
            session.getLocalSession().getChannel("/sync");
        if (channel != null) {
            channel.publish(LanternHub.settings());
            lastUpdateTime = System.currentTimeMillis();
        }
    }
}
