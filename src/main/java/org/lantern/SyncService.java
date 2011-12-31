package org.lantern;

import java.io.IOException;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;

import org.apache.commons.lang.StringUtils;
import org.codehaus.jackson.JsonParseException;
import org.codehaus.jackson.map.JsonMappingException;
import org.codehaus.jackson.map.ObjectMapper;
import org.cometd.bayeux.Message;
import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.ServerSession;
import org.cometd.java.annotation.Listener;
import org.cometd.java.annotation.Service;
import org.cometd.java.annotation.Session;
import org.jivesoftware.smack.packet.Presence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Function;

/**
 * Service for pushing updated Lantern state to the client.
 */
@Service("sync")
public class SyncService implements PresenceListener, LanternUpdateListener,
    ConnectivityListener {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Session
    private ServerSession session;
    
    private volatile long lastUpdateTime = System.currentTimeMillis();
    
    /**
     * Creates a new sync service.
     */
    public SyncService() {
        // Make sure the config class is added as a listener before this class.
        LanternHub.pubSub().addPresenceListener(this);
        LanternHub.pubSub().addUpdateListener(this);
        
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
        log.info("JSON: {}", message.getJSON());
        log.info("DATA: {}", message.getData());
        log.info("DATA CLASS: {}", message.getData().getClass());
        
        final String fullJson = message.getJSON();
        final String json = StringUtils.substringBetween(fullJson, "\"data\":", ",\"channel\":");
        final Map<String, Object> update = message.getDataAsMap();
        log.info("MAP: {}", update);

        final SettingsIo io = LanternHub.settingsIo();
        io.apply(update);
        log.info("Pushing updated config to browser...");
        sync();
    }

    @Override
    public void onUpdate(final UpdateData lanternUpdate) {
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
        log.info("Presence removed...");
        sync();
    }

    @Override
    public void presencesUpdated() {
        log.info("Got presences updated");
        sync();
    }
    
    @Override
    public void onConnectivityStateChanged(final ConnectivityStatus ct) {
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
