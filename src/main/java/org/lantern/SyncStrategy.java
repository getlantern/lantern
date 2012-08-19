package org.lantern;

import org.cometd.bayeux.server.ServerSession;

public interface SyncStrategy {

    void sync(boolean force, String channelName, ServerSession session);

}
