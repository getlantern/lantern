package org.lantern.state;

import org.cometd.bayeux.server.ServerSession;

/**
 * Interface for supporting various methods of syncing with clients using some
 * form of server-side push.
 */
public interface SyncStrategy {

    void sync(boolean force, SyncChannel channel, ServerSession session);

    void sync(boolean force, ServerSession session, String path, Object value);

}
