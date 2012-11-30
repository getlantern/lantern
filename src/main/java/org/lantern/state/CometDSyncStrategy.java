package org.lantern.state;

import org.cometd.bayeux.client.ClientSessionChannel;
import org.cometd.bayeux.server.ServerSession;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

/**
 * Strategy for syncing/pushing with the browser using cometd.
 */
@Singleton
public class CometDSyncStrategy implements SyncStrategy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long lastUpdateTime = System.currentTimeMillis();

    @Override
    public void sync(final boolean force,
        final ServerSession session, final String path, final Object value) {
        log.info("SYNCING");
        if (session == null) {
            log.info("No session...not syncing");
            return;
        }
        final long elapsed = System.currentTimeMillis() - lastUpdateTime;
        if (!force && elapsed < 100) {
            log.info("Not pushing more than 10 times a second...{} ms elapsed", 
                elapsed);
            return;
        }

        // We send all updates over the same channel.
        final ClientSessionChannel ch = 
            session.getLocalSession().getChannel("/sync");

        lastUpdateTime = System.currentTimeMillis();
        ch.publish(new SyncData(path, value));
        log.info("Sync performed");
    }

    /**
     * Helper class that formats data according to:
     * 
     * https://github.com/getlantern/lantern-ui/blob/master/SPECS.md
     */
    public static class SyncData {

        private final String path;
        private final Object value; 
        
        public SyncData(final SyncPath channel, final Object val) {
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
