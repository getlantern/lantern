package org.lantern;

/**
 * Listener for updates.
 */
public interface LanternUpdateListener {

    /**
     * Notifies the listener of a new update.
     * 
     * @param updateData The update.
     */
    void onUpdate(UpdateData updateData);
}
