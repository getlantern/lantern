package org.lantern.proxy.pt;

import io.netty.handler.codec.http.HttpRequest;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.util.Queue;

import javax.net.ssl.SSLEngine;

import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyAdapter;
import org.littleshoot.proxy.ChainedProxyManager;
import org.littleshoot.proxy.HttpProxyServerBootstrap;
import org.littleshoot.proxy.SslEngineSource;
import org.littleshoot.proxy.extras.SelfSignedSslEngineSource;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;

/**
 * <p>
 * This simple program runs two local LittleProxies that talk to each other
 * directly. After running this program, you can do this:
 * </p>
 * 
 * <pre>
 * curl -x 127.0.0.1:8080 http://www.google.com
 * </pre>
 */
public class ChainedMain {
    protected static InetAddress LOCALHOST;

    static {
        try {
            LOCALHOST = InetAddress.getByName("127.0.0.1");
        } catch (Exception e) {
            LOCALHOST = null;
            System.err.println("Unable to parse LOCALHOSt");
        }
    }

    protected static final int LITTLEPROXY_DOWNSTREAM_PORT = 8080;
    protected static final int LITTLEPROXY_UPSTREAM_PORT = 8083;

    public static void main(String[] args) throws Exception {
        new ChainedMain().run();
    }

    public void run() throws Exception {
        final SslEngineSource sslSource = new SelfSignedSslEngineSource();
        // Downstream LittleProxy connects to fteproxy client
        DefaultHttpProxyServer
                .bootstrap()
                .withName("Downstream")
                .withAddress(
                        new InetSocketAddress(LOCALHOST,
                                LITTLEPROXY_DOWNSTREAM_PORT))
                .withChainProxyManager(new ChainedProxyManager() {
                    @Override
                    public void lookupChainedProxies(HttpRequest httpRequest,
                            Queue<ChainedProxy> chainedProxies) {
                        chainedProxies.add(new ChainedProxyAdapter() {
                            @Override
                            public InetSocketAddress getChainedProxyAddress() {
                                return new InetSocketAddress(LOCALHOST,
                                        getUpstreamPort());
                            }

                            @Override
                            public boolean requiresEncryption() {
                                return ChainedMain.this.requiresEncryption();
                            }

                            @Override
                            public SSLEngine newSslEngine() {
                                return sslSource.newSslEngine();
                            }
                        });
                    }
                })
                .start();

        // Upstream LittleProxy
        HttpProxyServerBootstrap bootstrap = DefaultHttpProxyServer
                .bootstrap()
                .withName("Upstream")
                .withAddress(
                        new InetSocketAddress(LOCALHOST,
                                LITTLEPROXY_UPSTREAM_PORT));
        if (requiresEncryption()) {
            bootstrap.withSslEngineSource(sslSource);
        }
        bootstrap.start();
    }

    protected int getUpstreamPort() {
        return LITTLEPROXY_UPSTREAM_PORT;
    }

    protected boolean requiresEncryption() {
        return true;
    }

}
