package org.lantern.event;

import org.lantern.state.SyncPath;

/**
 * An event indicating the state of the specified channel should be synced with
 * clients.
 */
public class SyncEvent {

    private final String path;
    private final Object value;
    private final SyncType op;

    public SyncEvent(final SyncPath path, final Object value) {
        this(SyncType.ADD, path.getPath(), value);
    }

    public SyncEvent(final SyncType op, final SyncPath path, final Object value) {
        this(op, path.getPath(), value);
    }

    public SyncEvent(final String path, final Object value) {
        this(SyncType.ADD, path, value);
    }

    public SyncEvent(final SyncType op, final String path, final Object value) {
        this.op = op;
        this.path = path;
        this.value = value;
    }

    public String getPath() {
        return path;
    }

    public Object getValue() {
        return value;
    }

    public SyncType getOp() {
        return op;
    }

}
