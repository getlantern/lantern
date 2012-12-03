package org.lantern;

import java.security.Security;

import javax.net.ssl.SSLContext;

/**
 * Creates a client-side SSL context using a trust manager that only accepts
 * hard-coded certificates and hard-coded root signers -- sort of super 
 * certificate pinning.
 */
public class LanternClientSslContextFactory {

    private static final String PROTOCOL = "TLS";
    private final SSLContext CLIENT_CONTEXT;
    
    public LanternClientSslContextFactory(
        final LanternKeyStoreManager keyStoreManager) {
        String algorithm = 
            Security.getProperty("ssl.KeyManagerFactory.algorithm");
        if (algorithm == null) {
            algorithm = "SunX509";
        }

        try {
            final SSLContext clientContext = SSLContext.getInstance(PROTOCOL);
            clientContext.init(null, keyStoreManager.getTrustManagers(), null);
            CLIENT_CONTEXT = clientContext;
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the client-side SSLContext", e);
        }
        
    }

    public SSLContext getClientContext() {
        return CLIENT_CONTEXT;
    }
}
