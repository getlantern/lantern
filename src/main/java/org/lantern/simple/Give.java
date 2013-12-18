package org.lantern.simple;

import io.netty.handler.codec.http.HttpRequest;

import org.lantern.proxy.GiveModeHttpFilters;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersSourceAdapter;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.HttpProxyServerBootstrap;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * A really basic Give mode proxy that listens with both TCP and UDT and trusts
 * all Get proxies.
 * </p>
 * 
 * <p>
 * Run like this:
 * </p>
 * 
 * <pre>
 * ./launch org.lantern.simple.Give 46000 ../too-many-secrets/littleproxy_keystore.jks
 * </pre>
 */
public class Give {
    private static final Logger LOG = LoggerFactory.getLogger(Give.class);

    private String keyStorePath;
    private int tcpPort;
    private int udtPort;
    private HttpProxyServer server;

    public static void main(String[] args) throws Exception {
        new Give(args).start();
    }

    public Give(String[] args) {
        this.keyStorePath = args[1];
        this.tcpPort = Integer.parseInt(args[0]);
        this.udtPort = tcpPort + 1;
    }

    public void start() {
        startTcp();
        startUdt();

    }

    private void startTcp() {
        HttpProxyServerBootstrap bootstrap = DefaultHttpProxyServer
                .bootstrap()
                .withName("Give")
                .withPort(tcpPort)
                .withAllowLocalOnly(false)
                .withListenOnAllAddresses(true)
                .withSslEngineSource(new SimpleSslEngineSource(keyStorePath))
                .withAuthenticateSslClients(false)

                // Use a filter to deny requests to non-public ips
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(HttpRequest originalRequest) {
                        return new GiveModeHttpFilters(originalRequest);
                    }
                });

        LOG.info("Starting Give proxy at TCP port {}", tcpPort);
        server = bootstrap.start();
    }

    private void startUdt() {
        LOG.info("Starting Give proxy at UDT port {}", udtPort);
        server.clone().withPort(udtPort)
                .withTransportProtocol(TransportProtocol.UDT).start();
    }
}
