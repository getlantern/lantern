package org.lantern;

import javax.net.ssl.SSLEngine;

import org.jboss.netty.handler.ssl.SslHandler;
import org.littleshoot.proxy.HandshakeHandler;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.SslContextFactory;
import org.littleshoot.proxy.SslHandshakeHandler;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class CertTrackingSslHandlerFactory implements HandshakeHandlerFactory {

    private final KeyStoreManager ksm;
    
    @Inject
    public CertTrackingSslHandlerFactory(final KeyStoreManager ksm) {
        this.ksm = ksm;
    }

    /**
     * This method is called for every new pipeline that's created -- i.e.
     * for every new incoming connection to the server. We need to reload
     * the trust store each to make sure we take into account all the last
     * certificates from peers.
     */
    @Override
    public HandshakeHandler newHandshakeHandler() {
        final SslContextFactory scf = new SslContextFactory(ksm);
        final SSLEngine engine = scf.getServerContext().createSSLEngine();
        engine.setUseClientMode(false);
        engine.setNeedClientAuth(true);
        final SslHandler handler = new SslHandler(engine);
        return new SslHandshakeHandler("ssl", handler);
    }
}
