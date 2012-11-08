package org.lantern.state;

/**
 * An event indicating the state of the specified channel should be synced
 * with clients.
 */
public class SyncEvent {

    private final SyncChannel channel;

    public SyncEvent(final SyncChannel channel) {
        this.channel = channel;
    }

    public SyncChannel getChannel() {
        return channel;
    }

}
