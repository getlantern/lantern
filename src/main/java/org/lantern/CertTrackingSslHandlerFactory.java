package org.lantern;

import javax.net.ssl.SSLEngine;

import org.jboss.netty.handler.ssl.SslHandler;
import org.littleshoot.proxy.HandshakeHandler;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.SslHandshakeHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This class handles intercepting incoming SSL connections to the HTTP proxy
 * server, associating incoming client certificates with their associated
 * peers. Any incoming connections from non-trusted peers with non-trusted
 * certificates will be rejected.
 */
@Singleton
public class CertTrackingSslHandlerFactory implements HandshakeHandlerFactory {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final LanternTrustStore trustStore;
    
    @Inject
    public CertTrackingSslHandlerFactory(final KeyStoreManager ksm, 
        final LanternTrustStore trustStore) {
        this.trustStore = trustStore;
    }

    /**
     * This method is called for every new pipeline that's created -- i.e.
     * for every new incoming connection to the server. We need to reload
     * the trust store each time to make sure we take into account all the last
     * certificates from peers.
     */
    @Override
    public HandshakeHandler newHandshakeHandler() {
        log.debug("Creating new handshake handler...");
        //final TrustManager[] trustManagers = new TrustManager[]{this.trustManager};
        //final SslContextFactory scf = new SslContextFactory(ksm, trustManagers);
        final SSLEngine engine = trustStore.getServerContext().createSSLEngine();
        engine.setUseClientMode(false);
        engine.setNeedClientAuth(true);
        final SslHandler handler = new SslHandler(engine);
        return new SslHandshakeHandler("ssl", handler);
    }
}
