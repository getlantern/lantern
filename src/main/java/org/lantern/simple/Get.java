package org.lantern.simple;

import io.netty.handler.codec.http.HttpObject;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;

import java.net.InetSocketAddress;
import java.util.Queue;

import javax.net.ssl.SSLEngine;

import org.lantern.ProxyHolder;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyAdapter;
import org.littleshoot.proxy.ChainedProxyManager;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersAdapter;
import org.littleshoot.proxy.HttpFiltersSourceAdapter;
import org.littleshoot.proxy.HttpProxyServerBootstrap;
import org.littleshoot.proxy.SslEngineSource;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * A really basic Get mode proxy that trusts all Give proxies. Mostly for
 * experimentation purposes.
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
    private String authToken;
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
        this.authToken = args[2];
        if (args.length > 3) {
            transportProtocol = TransportProtocol.valueOf(args[3]);
        }
    }

    public void start() {
        HttpProxyServerBootstrap bootstrap = DefaultHttpProxyServer
                .bootstrap()
                .withName("Get")
                .withPort(localPort)
                .withAllowLocalOnly(true)
                .withListenOnAllAddresses(false)
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(HttpRequest originalRequest) {
                        return new HttpFiltersAdapter(originalRequest) {
                            @Override
                            public HttpResponse requestPre(HttpObject httpObject) {
                                if (httpObject instanceof HttpRequest) {
                                    HttpRequest req = (HttpRequest) httpObject;
                                    req.headers()
                                            .add(ProxyHolder.X_LANTERN_AUTH_TOKEN,
                                                    authToken);
                                }
                                return null;
                            }
                        };
                    }
                })
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

        LOG.info(
                "Starting Get proxy on port {} that connects upstream with {}",
                localPort,
                transportProtocol);
        bootstrap.start();
    }
}
