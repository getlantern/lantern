package org.lantern;

/**
 * Listener for updates.
 */
public interface LanternUpdateListener {

    /**
     * Notifies the listener of a new update.
     * 
     * @param lanternUpdate The update.
     */
    void onUpdate(LanternUpdate lanternUpdate);
}
