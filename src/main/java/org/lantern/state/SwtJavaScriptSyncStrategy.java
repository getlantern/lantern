package org.lantern.state;

import org.cometd.bayeux.server.ServerSession;
import org.lantern.LanternHub;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Strategy for syncing/pushing with the browser using direct calls to 
 * JavaScript from the SWT browser widget.
 */
public class SwtJavaScriptSyncStrategy implements SyncStrategy {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private volatile long lastUpdateTime = System.currentTimeMillis();
    
    @Override
    public void sync(final boolean force, final SyncChannel channel, 
        final ServerSession session) {
        final long elapsed = System.currentTimeMillis() - lastUpdateTime;
        if (!force && elapsed < 100) {
            log.debug("Not pushing more than 10 times a second...{} ms elapsed", 
                elapsed);
            return;
        }

        switch (channel) {
            case roster:
                log.debug("Syncing roster...");
                LanternHub.dashboard().rosterSync();
                break;
            case settings:
                LanternHub.dashboard().settingsSync();
                break;
            default:
                throw new Error("Bad channel? "+channel.name());
        }
        lastUpdateTime = System.currentTimeMillis();
        log.debug("Sync performed");
    }
}
