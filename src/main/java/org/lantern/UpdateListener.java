package org.lantern;

import java.util.Map;

/**
 * Listener for update data.
 */
public interface UpdateListener {

    /**
     * Called when there's an update.
     * 
     * @param updateData The data for the update.
     */
    void onUpdate(Map<String, String> updateData);
}
