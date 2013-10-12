package org.lantern.network;

/**
 * Listener for events emitted by the {@link NetworkTracker}.
 * 
 * @param <U>
 * @param <F>
 * @param <D>
 */
public interface NetworkTrackerListener<U, F, D> {
    /**
     * An instance became online and trusted.
     * 
     * @param instance
     */
    void instanceOnlineAndTrusted(InstanceInfoWithCert<U, F, D> instance);

    /**
     * An instance stopped being online and trusted.
     * 
     * @param instance
     */
    void instanceOfflineOrUntrusted(InstanceInfoWithCert<U, F, D> instance);
}
