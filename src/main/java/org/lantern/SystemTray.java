package org.lantern;


/**
 * Interface for system tray implementations.
 */
public interface SystemTray extends LanternService {

    void createTray();

    boolean isActive();

    boolean isSupported();

}
