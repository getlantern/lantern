package org.lantern.state;

import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.ServerSession;
import org.lantern.LanternHub;
import org.lantern.LanternUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Strategy for syncing/pushing with the browser using cometd.
 */
public class CometDSyncStrategy implements SyncStrategy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long lastUpdateTime = System.currentTimeMillis();

    @Override
    public void sync(final boolean force,
        final ServerSession session, final String path, final Object value) {
        if (session == null) {
            log.debug("No session...not syncing");
            return;
        }
        final long elapsed = System.currentTimeMillis() - lastUpdateTime;
        if (!force && elapsed < 100) {
            log.debug("Not pushing more than 10 times a second...{} ms elapsed", 
                elapsed);
            return;
        }

        //final String channelName = "/sync/"+channel.name();
        
        // We send all updates over the same channel.
        final ClientSessionChannel ch = 
            session.getLocalSession().getChannel("/sync");
    
        //final Object obj = getValueForPath(path);
        final SyncData syncer = new SyncData(path, value);
        lastUpdateTime = System.currentTimeMillis();

        // Need to specify the full path here somehow...
        ch.publish(syncer);
        log.debug("Sync performed");
    }
    
    @Override
    public void sync(final boolean force, final SyncChannel channel, 
        final ServerSession session) {
        if (session == null) {
            log.debug("No session...not syncing");
            return;
        }
        final long elapsed = System.currentTimeMillis() - lastUpdateTime;
        if (!force && elapsed < 100) {
            log.debug("Not pushing more than 10 times a second...{} ms elapsed", 
                elapsed);
            return;
        }
        if (channel != null) {
            //final String channelName = "/sync/"+channel.name();
            
            // We send all updates over the same channel.
            final ClientSessionChannel ch = 
                session.getLocalSession().getChannel("/sync");
        
            final SyncData syncer;
            switch(channel) {
                case model:
                    log.debug("Syncing model...");
                    syncer = new SyncData("", LanternHub.getModel());
                    break;
                case roster:
                    log.debug("Syncing roster...");
                    syncer = new SyncData(channel, LanternHub.xmppHandler().getRoster());
                    break;
                case settings:
                    syncer = new SyncData(channel, LanternHub.settings());
                    break;
                case transfers:
                    syncer = new SyncData(channel, LanternHub.settings().getTransfers());
                    break;
                case connectivity:
                    syncer = new SyncData(channel, LanternHub.settings().getConnectivity());
                    break;
                case version:
                    syncer = new SyncData(channel, LanternHub.settings().getVersion());
                    
                    break;
                default:
                    throw new Error("Bad channel: "+ channel);
            }
            lastUpdateTime = System.currentTimeMillis();

            // Need to specify the full path here somehow...
            ch.publish(syncer);
            log.debug("Sync performed");
        };
    }
    

    /**
     * Helper class that formats data according to:
     * 
     * https://github.com/getlantern/lantern-ui/blob/master/SPECS.md
     */
    public static class SyncData {

        private final String path;
        private final Object value; 
        
        public SyncData(final SyncChannel channel, final Object val) {
            this(channel.name(), val);
        }
        
        public SyncData(final String path, final Object val) {
            this.path = path;
            this.value = val;
        }

        public String getPath() {
            return path;
        }

        public Object getValue() {
            return value;
        }
    }
}
