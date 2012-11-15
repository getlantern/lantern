package org.lantern.state;

/**
 * The available channels to sync on.
 */
public enum SyncChannel {

    settings,
    roster,
    transfers,
    connectivity,
    version,
    
    /**
     * This channel contains the entire state model, including all other
     * sub-channels. 
     */
    model,
}
