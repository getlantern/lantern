package org.lantern;

public class LanternHub {

    private static TrustedContactsManager trustedContactsManager;
    
    private static LanternBrowser lanternBrowser;

    public static TrustedContactsManager getTrustedContactsManager() {
        if (trustedContactsManager == null) {
            trustedContactsManager = new DefaultTrustedContactsManager();
        } 
        return trustedContactsManager;
    }

    public static LanternBrowser getLanternBrowser() {
        if (lanternBrowser == null) {
            lanternBrowser = new LanternBrowser();
        }
        return lanternBrowser;
    }

}
