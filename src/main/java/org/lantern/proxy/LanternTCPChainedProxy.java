package org.lantern.proxy;

import java.net.InetSocketAddress;

import javax.net.ssl.SSLEngine;

import org.lantern.LanternTrustStore;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyAdapter;
import org.littleshoot.util.FiveTuple;

/**
 * {@link ChainedProxy} that communicates downstream over TCP and uses
 * {@link LanternTrustStore} for encryption and authentication.
 */
public class LanternTCPChainedProxy extends ChainedProxyAdapter {
    private InetSocketAddress chainedProxyAddress;
    private LanternTrustStore trustStore;

    public LanternTCPChainedProxy(FiveTuple fiveTuple,
            LanternTrustStore trustStore) {
        super();
        this.chainedProxyAddress = fiveTuple.getRemote();
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
