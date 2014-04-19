package org.lantern.simple;

import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpRequest;

import java.util.HashSet;
import java.util.Set;

import org.apache.commons.cli.Option;
import org.lantern.proxy.GiveModeHttpFilters;
import org.littleshoot.proxy.HttpFilters;
import org.littleshoot.proxy.HttpFiltersSourceAdapter;
import org.littleshoot.proxy.HttpProxyServer;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.proxy.impl.DefaultHttpProxyServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * A really basic Give mode proxy that listens with both TCP and UDT and trusts
 * all Get proxies. Mostly for experimentation purposes.
 * </p>
 * 
 * <p>
 * Run like this:
 * </p>
 * 
 * <pre>
 * ./launch org.lantern.simple.Give -host 127.0.0.1 -http 46000 -https 46001 -udt 46002 -keystore ../too-many-secrets/littleproxy_keystore.jks -authtoken '534#^#$523590)'
 * </pre>
 * 
 * <pre>
 * usage: ./launch org.lantern.simple.Give [options]
 *  -authtoken <arg>   Auth token that this proxy requires from its clients.
 *                     Defaults to '534#^#$523590)'.
 *  -host <arg>        (Required) The proxy's public hostname or ip address
 *  -http <arg>        HTTP listen port.  Defaults to 80.
 *  -https <arg>       HTTPS listen port.  Defaults to 443.
 *  -keystore <arg>    Path to keystore containing proxy's cert.  Defaults to
 *                     ../too-many-secrets/littleproxy_keystore.jks
 *  -udt <arg>         UDT listen port.  Defaults to 9090.
 * </pre>
 */
public class Give extends CliProgram {
    private static final Logger LOG = LoggerFactory.getLogger(Give.class);
    // Http Methods known to Apache
    private static final Set<HttpMethod> KNOWN_METHODS = new HashSet<HttpMethod>();
    private static final Set<HttpMethod> ALLOWED_METHODS = new HashSet<HttpMethod>();
    private static final Set<String> KNOWN_URIS = new HashSet<String>();
    private static final Set<String> BAD_URIS = new HashSet<String>();
    private static final String OPT_HOST = "host";
    private static final String OPT_HTTP_PORT = "http";
    private static final String OPT_HTTPS_PORT = "https";
    private static final String OPT_UDT_PORT = "udt";
    private static final String OPT_KEYSTORE = "keystore";
    private static final String OPT_AUTHTOKEN = "authtoken";

    private String host;
    private int httpsPort;
    private int httpPort;
    private int udtPort;
    private String keyStorePath;
    private String expectedAuthToken;
    private HttpProxyServer server;

    public static void main(String[] args) throws Exception {
        new Give(args).start();
    }

    public Give(String[] args) {
        super(args);
        this.host = cmd.getOptionValue(OPT_HOST);
        this.httpPort = Integer.parseInt(cmd
                .getOptionValue(OPT_HTTP_PORT, "80"));
        this.httpsPort = Integer.parseInt(cmd.getOptionValue(OPT_HTTPS_PORT,
                "443"));
        this.udtPort = Integer.parseInt(cmd.getOptionValue(OPT_UDT_PORT,
                "9090"));
        this.keyStorePath = cmd.getOptionValue(OPT_KEYSTORE,
                "../too-many-secrets/littleproxy_keystore.jks");
        this.expectedAuthToken = cmd.getOptionValue(OPT_AUTHTOKEN,
                "534#^#$523590)");
    }

    public void start() {
        System.out.println(String
                .format("Starting Give proxy with the following settings ...\n"
                        +
                        "Host: %1$s\n" +
                        "HTTP port: %2$s\n" +
                        "HTTPS port: %3$s\n" +
                        "UDT port: %4$s\n" +
                        "Keystore path: %5$s\n" +
                        "Auth token: %6$s\n",
                        host,
                        httpPort,
                        httpsPort,
                        udtPort,
                        keyStorePath,
                        expectedAuthToken));
        startTcp();
        startUdt();
    }

    protected void initializeCliOptions() {
        //@formatter:off
        addOption(new Option(OPT_HOST, true, "(Required) The proxy's public hostname or ip address"), true);
        addOption(new Option(OPT_HTTP_PORT, true, "HTTP listen port.  Defaults to 80."), false);
        addOption(new Option(OPT_HTTPS_PORT, true, "HTTPS listen port.  Defaults to 443."), false);
        addOption(new Option(OPT_UDT_PORT, true, "UDT listen port.  Defaults to 9090."), false);
        addOption(new Option(OPT_KEYSTORE, true, "Path to keystore containing proxy's cert.  Defaults to ../too-many-secrets/littleproxy_keystore.jks"), false);
        addOption(new Option(OPT_AUTHTOKEN, true, "Auth token that this proxy requires from its clients.  Defaults to '534#^#$523590)'."), false);
        //@formatter:on
    }

    private void startTcp() {
        LOG.info("Starting Plain Text Give proxy at TCP port {}", httpPort);
        DefaultHttpProxyServer.bootstrap()
                .withName("Give-PlainText")
                .withPort(httpPort)
                .withAllowLocalOnly(false)
                .withListenOnAllAddresses(true)
                // Use a filter to respond with 404 to http requests
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(
                            HttpRequest originalRequest,
                            ChannelHandlerContext ctx) {
                        return new GiveModeHttpFilters(originalRequest, ctx,
                                host,
                                httpPort, TransportProtocol.TCP,
                                expectedAuthToken);
                    }
                })
                .start();

        LOG.info(
                "Starting TLS Give proxy at TCP port {}", httpsPort);
        server = DefaultHttpProxyServer.bootstrap()
                .withName("Give-Encrypted")
                .withPort(httpsPort)
                .withAllowLocalOnly(false)
                .withListenOnAllAddresses(true)
                .withSslEngineSource(new SimpleSslEngineSource(keyStorePath))
                .withAuthenticateSslClients(false)

                // Use a filter to deny requests other than those contains the
                // right auth token
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(
                            HttpRequest originalRequest,
                            ChannelHandlerContext ctx) {
                        return new GiveModeHttpFilters(originalRequest, ctx,
                                host,
                                httpsPort, TransportProtocol.TCP,
                                expectedAuthToken);
                    }
                })
                .start();
    }

    private void startUdt() {
        LOG.info("Starting Give proxy at UDT port {}", udtPort);
        server.clone()
                .withName("Give-UDT")
                .withPort(udtPort)
                .withTransportProtocol(TransportProtocol.UDT)

                // Use a filter to deny requests other than those contains the
                // right auth token
                .withFiltersSource(new HttpFiltersSourceAdapter() {
                    @Override
                    public HttpFilters filterRequest(
                            HttpRequest originalRequest,
                            ChannelHandlerContext ctx) {
                        return new GiveModeHttpFilters(originalRequest, ctx,
                                host,
                                udtPort, TransportProtocol.UDT,
                                expectedAuthToken);
                    }
                })
                .start();
    }

}
