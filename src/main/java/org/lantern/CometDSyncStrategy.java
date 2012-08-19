package org.lantern;

import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.ServerSession;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Strategy for syncing/pushing with the browser using cometd.
 */
public class CometDSyncStrategy implements SyncStrategy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long lastUpdateTime = System.currentTimeMillis();
    
    @Override
    public void sync(final boolean force, final String channelName, 
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
        final ClientSessionChannel channel = 
            session.getLocalSession().getChannel(channelName);
        
        if (channel != null) {
            final Object syncer;
            if (channelName.equals(LanternConstants.ROSTER_SYNC_CHANNEL)) {
                log.debug("Syncing roster...");
                syncer = LanternHub.xmppHandler().getRoster();
            } else if (channelName.equals(LanternConstants.SETTINGS_SYNC_CHANNEL)) {
                syncer = LanternHub.settings();
            } else {
                throw new Error("Bad channel name?");
            }
            lastUpdateTime = System.currentTimeMillis();
            channel.publish(syncer);
            log.debug("Sync performed");
        };
    }
}
