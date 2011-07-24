package org.lantern;

import org.eclipse.swt.widgets.Display;

public class LanternHub {

    private volatile static TrustedContactsManager trustedContactsManager;
    private volatile static Display display;
    private volatile static SystemTray systemTray;
    
    private volatile static StatsTracker statsTracker;
    
    public synchronized static TrustedContactsManager getTrustedContactsManager() {
        if (trustedContactsManager == null) {
            trustedContactsManager = new DefaultTrustedContactsManager();
        } 
        return trustedContactsManager;
    }

    public synchronized static Display display() {
        if (display == null) {
            display = new Display();
        }
        return display;
    }

    public synchronized static SystemTray systemTray() {
        if (systemTray == null) {
            systemTray = new SystemTrayImpl(display());
            systemTray.createTray();
        }
        return systemTray;
    }

    public synchronized static StatsTracker statsTracker() {
        if (statsTracker == null) {
            statsTracker = new StatsTracker();
        }
        return statsTracker;
    }

}
