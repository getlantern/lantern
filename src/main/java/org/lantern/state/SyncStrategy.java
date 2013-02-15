package org.lantern.state;

import org.cometd.bayeux.server.ServerSession;
import org.lantern.event.SyncType;

/**
 * Interface for supporting various methods of syncing with clients using some
 * form of server-side push.
 */
public interface SyncStrategy {

    void sync(ServerSession session, SyncType syncType, String path,
            Object value);

}
