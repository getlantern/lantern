package org.lantern;

import java.net.InetSocketAddress;

import javax.net.ssl.SSLEngine;

import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyAdapter;

/**
 * {@link ChainedProxy} that communicates downstream over TCP and uses
 * {@link LanternTrustStore} for encryption and authentication.
 */
public class TcpChainedProxy extends ChainedProxyAdapter {
    private InetSocketAddress chainedProxyAddress;
    private LanternTrustStore trustStore;

    public TcpChainedProxy(InetSocketAddress chainedProxyAddress,
            LanternTrustStore trustStore) {
        super();
        this.chainedProxyAddress = chainedProxyAddress;
        this.trustStore = trustStore;
    }

    @Override
    public InetSocketAddress getChainedProxyAddress() {
        return chainedProxyAddress;
    }

    @Override
    public boolean requiresEncryption() {
        return true;
    }

    @Override
    public SSLEngine newSSLEngine() {
        return trustStore.getSslContext().createSSLEngine();
    }
}
