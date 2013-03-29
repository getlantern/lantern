package org.lantern;

import javax.net.ssl.SSLEngine;

import org.jboss.netty.handler.ssl.SslHandler;
import org.littleshoot.proxy.HandshakeHandler;
import org.littleshoot.proxy.HandshakeHandlerFactory;
import org.littleshoot.proxy.KeyStoreManager;
import org.littleshoot.proxy.SslContextFactory;
import org.littleshoot.proxy.SslHandshakeHandler;

public class CertTrackingSslHandlerFactory implements HandshakeHandlerFactory {

    private final KeyStoreManager ksm;
    
    public CertTrackingSslHandlerFactory(final KeyStoreManager ksm) {
        this.ksm = ksm;
    }
        
    @Override
    public HandshakeHandler newHandshakeHandler() {
        final SslContextFactory scf = new SslContextFactory(ksm);
        final SSLEngine engine = scf.getServerContext().createSSLEngine();
        engine.setUseClientMode(false);
        return new SslHandshakeHandler("ssl", new SslHandler(engine));
    }
}
