package org.lantern.state;

import org.cometd.bayeux.server.ServerSession;
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
    public void sync(boolean force, ServerSession session, String path,
            Object value) {
        final long elapsed = System.currentTimeMillis() - lastUpdateTime;
        if (!force && elapsed < 100) {
            log.debug("Not pushing more than 10 times a second...{} ms elapsed", 
                elapsed);
            return;
        }

        lastUpdateTime = System.currentTimeMillis();
        log.debug("Sync performed");
    }
}
