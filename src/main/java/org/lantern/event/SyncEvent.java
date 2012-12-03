package org.lantern.event;

import org.lantern.state.SyncPath;


/**
 * An event indicating the state of the specified channel should be synced
 * with clients.
 */
public class SyncEvent {

    private final String path;
    private final Object value;
    
    public SyncEvent(final SyncPath path, final Object value) {
        this.path = path.getEnumPath();
        this.value = value;
    }
    
    public String getPath() {
        return path;
    }

    public Object getValue() {
        return value;
    }
}
