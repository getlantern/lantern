package org.lantern;

import java.security.Security;

import javax.net.ssl.SSLContext;

import org.littleshoot.proxy.KeyStoreManager;

public class LanternClientSslContextFactory {

    private static final String PROTOCOL = "TLS";
    private final SSLContext CLIENT_CONTEXT;
    
    public LanternClientSslContextFactory(final KeyStoreManager ksm) {
        String algorithm = Security.getProperty("ssl.KeyManagerFactory.algorithm");
        if (algorithm == null) {
            algorithm = "SunX509";
        }

        SSLContext clientContext = null;
        try {
            clientContext = SSLContext.getInstance(PROTOCOL);
            clientContext.init(null, ksm.getTrustManagers(), null);
        } catch (final Exception e) {
            throw new Error(
                    "Failed to initialize the client-side SSLContext", e);
        }
        CLIENT_CONTEXT = clientContext;
    }

    public SSLContext getClientContext() {
        return CLIENT_CONTEXT;
    }
}
