package org.lantern;

import java.util.Map;

/**
 * Interface for system tray implementations.
 */
public interface SystemTray {

    void createTray();

    void activate();

    void addUpdate(Map<String, String> updateData);

}
