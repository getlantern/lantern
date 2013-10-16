package org.lantern.network;

/**
 * Listener for events emitted by the {@link NetworkTracker}.
 * 
 * @param <I>
 *            Type of object identifying instances
 * @param <D>
 *            Type of object representing additional data stored in
 *            {@link InstanceInfo}s
 */
public interface NetworkTrackerListener<I, D> {
    /**
     * An trusted instance became online.
     * 
     * @param instance
     */
    void instanceOnlineAndTrusted(InstanceInfo<I, D> instance);

    /**
     * An instance stopped being online and/or trusted.
     * 
     * @param instance
     */
    void instanceOfflineOrUntrusted(InstanceInfo<I, D> instance);
}
