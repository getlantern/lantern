package org.lantern;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import com.google.common.base.Preconditions;
import com.google.inject.Singleton;

/**
 * Peer certificate tracker.
 */
@Singleton
public class DefaultCertTracker implements CertTracker {

    private final Map<String, String> certToJid = 
            new ConcurrentHashMap<String, String>();
    
    private final Map<String, String> jidToCert = 
            new ConcurrentHashMap<String, String>();
    
    @Override
    public void addCert(final String base64Cert, final String fullJid) {
        Preconditions.checkArgument(fullJid.contains("/"), 
            "Full JID required. Found %s", fullJid);
        this.certToJid.put(base64Cert, fullJid);
        this.jidToCert.put(fullJid, base64Cert);
    }

    @Override
    public String getCertForJid(final String fullJid) {
        return this.jidToCert.get(fullJid);
    }

    @Override
    public String toString() {
        return "DefaultCertTracker [certToJid=" + certToJid + "\njidToCert="
                + jidToCert + "]";
    }
}
