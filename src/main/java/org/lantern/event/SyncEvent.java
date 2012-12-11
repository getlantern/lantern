package org.lantern.event;

import org.lantern.state.SyncPath;


/**
 * An event indicating the state of the specified channel should be synced
 * with clients.
 */
public class SyncEvent {

    private final SyncPath path;
    private final Object value;
    
    public SyncEvent(final SyncPath path, final Object value) {
        this.path = path;
        this.value = value;
    }

    public SyncPath getPath() {
        return path;
    }

    public Object getValue() {
        return value;
    }

}
