package org.lantern;

import java.io.IOException;

import org.jivesoftware.smack.proxy.ProxyInfo;

/**
 * Exception when connecting to an HTTP proxy.
 */
public class ProxyException extends IOException {
    
    /**
     * Generated ID.
     */
    private static final long serialVersionUID = -5651896437306070120L;

    public ProxyException(final ProxyInfo.ProxyType type, final String ex, 
        final Throwable cause) {
        super("Proxy Exception " + type.toString() + " : " + ex + ", " + cause);
    }

    public ProxyException(final ProxyInfo.ProxyType type, final String ex) {
        super("Proxy Exception " + type.toString() + " : " + ex);
    }

    public ProxyException(final ProxyInfo.ProxyType type) {
        super("Proxy Exception " + type.toString() + " : " + "Unknown Error");
    }
}
