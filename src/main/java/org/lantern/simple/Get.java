package org.lantern.simple;

import io.netty.handler.codec.http.HttpRequest;

import java.net.InetSocketAddress;
import java.util.Queue;

import javax.net.ssl.SSLEngine;

import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyAdapter;
import org.littleshoot.proxy.ChainedProxyManager;
import org.littleshoot.proxy.HttpProxyServerBootstrap;
import org.littleshoot.proxy.SslEngineSource;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * A really basic Get mode proxy and that trusts all Give proxies.
 * </p>
 * 
 * <p>
 * Run like this:
 * </p>
 * 
 * <pre>
 * ./launch org.lantern.simple.Get 47000 127.0.0.1:46001 UDT
 * </pre>
 * 
 * <p>
 * 127.0.0.1:46000 is the Give proxy's address, 47000 is the Get proxy's local
 * port. The third parameter is the transport protocol and can be either TCP or
 * UDT. If omitted, defaults to TCP.
 * </p>
 */
public class Get {
    private static final Logger LOG = LoggerFactory.getLogger(Get.class);

    private int localPort;
    private InetSocketAddress giveAddress;
    private TransportProtocol transportProtocol = TransportProtocol.TCP;
    private SslEngineSource sslEngineSource = new SimpleSslEngineSource();

    public static void main(String[] args) throws Exception {
        new Get(args).start();
    }

    public Get(String[] args) {
        this.localPort = Integer.parseInt(args[0]);
        String[] parts = args[1].split(":");
        this.giveAddress = new InetSocketAddress(parts[0],
                Integer.parseInt(parts[1]));
        if (args.length > 2) {
            transportProtocol = TransportProtocol.valueOf(args[2]);
        }
    }

    public void start() {
        HttpProxyServerBootstrap bootstrap = DefaultHttpProxyServer
                .bootstrap()
                .withName("Get")
                .withPort(localPort)
                .withAllowLocalOnly(true)
                .withListenOnAllAddresses(false)
                .withChainProxyManager(new ChainedProxyManager() {
                    @Override
                    public void lookupChainedProxies(HttpRequest httpRequest,
                            Queue<ChainedProxy> chainedProxies) {
                        chainedProxies.add(new ChainedProxyAdapter() {
                            @Override
                            public InetSocketAddress getChainedProxyAddress() {
                                return giveAddress;
                            }

                            @Override
                            public TransportProtocol getTransportProtocol() {
                                return transportProtocol;
                            }

                            @Override
                            public boolean requiresEncryption() {
                                return true;
                            }

                            @Override
                            public SSLEngine newSslEngine() {
                                return sslEngineSource.newSslEngine();
                            }
                        });
                    }
                });

        LOG.info("Starting Get proxy at {} port {}", transportProtocol,
                localPort);
        bootstrap.start();
    }
}
