package org.lantern.simple;

import io.netty.handler.codec.http.HttpRequest;

import java.net.InetSocketAddress;
import java.util.Queue;

import javax.net.ssl.SSLEngine;

import org.apache.commons.cli.Option;
import org.lantern.proxy.BaseChainedProxy;
import org.littleshoot.proxy.ChainedProxy;
import org.littleshoot.proxy.ChainedProxyManager;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.HttpProxyServerBootstrap;
import org.littleshoot.proxy.SslEngineSource;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;

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
 * ./launch org.lantern.simple.Get -port 47000 -remote 127.0.0.1:46002 -authtoken '534#^#$523590)' -protocol UDT
 * </pre>
 * 
 * <pre>
 * usage: ./launch org.lantern.simple.Get [options]
 *  -authtoken <arg>   The auth token required by the remote proxy.  Defaults
 *                     to '534#^#$523590)'.
 *  -port <arg>        The local proxy's port.  Defaults to 443.
 *  -protocol <arg>    The protocol (TCP or UDT).  Defaults to TCP.
 *  -remote <arg>      (Required) The remote proxy's host:port
 * </pre>
 */
public class Get extends CliProgram {
    private static final String OPT_PORT = "port";
    private static final String OPT_REMOTE = "remote";
    private static final String OPT_AUTHTOKEN = "authtoken";
    private static final String OPT_PROTOCOL = "protocol";

    private int localPort;
    private InetSocketAddress giveAddress;
    private String authToken;
    private TransportProtocol transportProtocol = TransportProtocol.TCP;
    private SslEngineSource sslEngineSource = new SimpleSslEngineSource();
    private HttpProxyServer server;

    public static void main(String[] args) throws Exception {
        new Get(args).start();
    }

    public Get(String[] args) {
        super(args);
        this.localPort = Integer
                .parseInt(cmd.getOptionValue(OPT_PORT, "443"));
        String[] remote = cmd.getOptionValue(OPT_REMOTE).split(":");
        this.giveAddress = new InetSocketAddress(remote[0],
                Integer.parseInt(remote[1]));
        this.authToken = cmd.getOptionValue(OPT_AUTHTOKEN, "534#^#$523590)");
        this.transportProtocol = TransportProtocol.valueOf(cmd
                .getOptionValue(OPT_PROTOCOL, "TCP"));
    }

    public Get(int localPort,
            String giveAddress,
            String authToken,
            TransportProtocol transportProtocol) {
        this(
                new String[] {
                        "-" + OPT_PORT, Integer.toString(localPort),
                        "-" + OPT_REMOTE, giveAddress,
                        "-" + OPT_AUTHTOKEN, authToken,
                        "-" + OPT_PROTOCOL, transportProtocol.toString() });
    }

    @Override
    protected void initializeCliOptions() {
        // @formatter:off
        addOption(new Option(OPT_REMOTE, true, "(Required) The remote proxy's host:port"), true);
        addOption(new Option(OPT_PORT, true, "The local proxy's port.  Defaults to 443."), false);
        addOption(new Option(OPT_AUTHTOKEN, true, "The auth token required by the remote proxy.  Defaults to '534#^#$523590)'."), false);
        addOption(new Option(OPT_PROTOCOL, true, "The protocol (TCP or UDT).  Defaults to TCP."), false);
        // @formatter:on
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
                        chainedProxies.add(new BaseChainedProxy(authToken) {
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

        System.out.println(String
                .format("Starting Get proxy with the following settings ...\n" +
                        "Local port: %1$s\n" +
                        "Remote proxy: %2$s\n" +
                        "Auth token: %3$s\n" +
                        "Protocol: %4$s",
                        localPort,
                        giveAddress,
                        authToken,
                        transportProtocol));
        server = bootstrap.start();
    }

    public void stop() {
        server.stop();
    }
}
