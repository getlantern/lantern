package org.lantern;

import org.eclipse.swt.widgets.Display;

public class LanternHub {

    private static TrustedContactsManager trustedContactsManager;
    private static Display display;
    private static SystemTray systemTray;
    
    public static TrustedContactsManager getTrustedContactsManager() {
        if (trustedContactsManager == null) {
            trustedContactsManager = new DefaultTrustedContactsManager();
        } 
        return trustedContactsManager;
    }

    public static Display display() {
        if (display == null) {
            display = new Display();
        }
        return display;
    }

    public static SystemTray systemTray() {
        if (systemTray == null) {
            systemTray = new SystemTrayImpl(display());
            systemTray.createTray();
        }
        return systemTray;
    }

}
