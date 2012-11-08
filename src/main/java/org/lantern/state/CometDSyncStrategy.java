package org.lantern.state;

import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.ServerSession;
import org.lantern.LanternHub;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Strategy for syncing/pushing with the browser using cometd.
 */
public class CometDSyncStrategy implements SyncStrategy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long lastUpdateTime = System.currentTimeMillis();
    
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
            final String channelName = "/sync/"+channel.name();
            final ClientSessionChannel ch = 
                session.getLocalSession().getChannel(channelName);
        
            final Object syncer;
            switch(channel) {
                case roster:
                    log.debug("Syncing roster...");
                    syncer = LanternHub.xmppHandler().getRoster();
                    break;
                case settings:
                    syncer = LanternHub.settings();
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
            log.debug("Sync performed on {}", channelName);
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
            this.path = channel.name();
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
