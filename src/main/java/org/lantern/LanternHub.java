package org.lantern;

public class LanternHub {

    private static TrustedContactsManager trustedContactsManager;
    
    public static TrustedContactsManager getTrustedContactsManager() {
        if (trustedContactsManager == null) {
            trustedContactsManager = new DefaultTrustedContactsManager();
        } 
        return trustedContactsManager;
    }

}
