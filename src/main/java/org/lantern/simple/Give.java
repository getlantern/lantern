package org.lantern.simple;

import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.http.HttpRequest;

import java.net.InetSocketAddress;
import java.util.Properties;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionBuilder;
import org.lantern.Cli;
import org.lantern.LanternUtils;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.monitoring.Stats;
import org.lantern.monitoring.StatsManager;
import org.lantern.monitoring.StatshubAPI;
import org.lantern.proxy.GiveModeActivityTracker;
import org.lantern.proxy.GiveModeHttpFilters;
import org.lantern.proxy.pt.PluggableTransport;
import org.lantern.proxy.pt.PluggableTransports;
import org.lantern.proxy.pt.PtType;
import org.lantern.state.InstanceStats;
import org.lantern.util.Threads;
import org.littleshoot.proxy.ActivityTracker;
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
 * all Get proxies. This proxy is useful for experimentation and is also used
 * for fallback proxies.
 * </p>
 * 
 * <p>
 * Run like this:
 * </p>
 * 
 * <pre>
 * ./launch -Xmx400m org.lantern.simple.Give -instanceid mytestfallback -host 127.0.0.1 -http 46000 -https 46001 -udt 46002 -keystore ../too-many-secrets/littleproxy_keystore.jks -authtoken '534#^#$523590)'
 * </pre>
 * 
 * <pre>
 * usage: ./launch org.lantern.simple.Give [options]
 *  -authtoken <arg>           Auth token that this proxy requires from its
 *                             clients.  Defaults to '534#^#$523590)'.
 *  -host <arg>                (Required) The proxy's public hostname or ip
 *                             address
 *  -http <arg>                HTTP listen port.  Defaults to 80.
 *  -https <arg>               HTTPS listen port.  Defaults to 443.
 *  -instanceid <arg>          The instanceid.  If specified, stats will be
 *                             reported under this instance id.  Otherwise,
 *                             stats will not be reported.
 *  -keystore <arg>            Path to keystore containing proxy's cert.
 *                             Defaults to
 *                             ../too-many-secrets/littleproxy_keystore.jks
 *     --pt <property=value>   (Optional) Specify pluggable transport
 *                             properties
 *  -udt <arg>                 UDT listen port.
 * </pre>
 */
public class Give extends CliProgram {
    private static final Logger LOGGER = LoggerFactory.getLogger(Give.class);

    private static final String OPT_HOST = "host";
    private static final String OPT_HTTP_PORT = "http";
    private static final String OPT_HTTPS_PORT = "https";
    private static final String OPT_UDT_PORT = "udt";
    private static final String OPT_KEYSTORE = "keystore";
    private static final String OPT_AUTHTOKEN = "authtoken";
    private static final String OPT_INSTANCE_ID = "instanceid";
    private static final String OPT_PT = "pt";

    private String host;
    private int httpsPort;
    private int httpPort;
    private Integer udtPort;
    private String keyStorePath;
    private String expectedAuthToken;
    private String instanceId;
    private PluggableTransport pt;

    private HttpProxyServer server;
    private InstanceStats stats = new InstanceStats();
    private GeoIpLookupService lookupService = new GeoIpLookupService();
    private ActivityTracker activityTracker = new GiveModeActivityTracker(
            stats, lookupService, null);
    private final StatshubAPI statshub = new StatshubAPI();

    private final ScheduledExecutorService statsScheduler = Threads
            .newSingleThreadScheduledExecutor("PostStats");

    public static void main(String[] args) throws Exception {
        new Give(args).start();
    }

    public Give(String[] args) {
        super(args);
        LanternUtils.setFallbackProxy(true);
        this.host = cmd.getOptionValue(OPT_HOST);
        this.httpPort = Integer.parseInt(cmd
                .getOptionValue(OPT_HTTP_PORT, "80"));
        this.httpsPort = Integer.parseInt(cmd.getOptionValue(OPT_HTTPS_PORT,
                "443"));
        if (cmd.hasOption(OPT_UDT_PORT)) {
            this.udtPort = Integer.parseInt(cmd.getOptionValue(OPT_UDT_PORT));
        }
        this.keyStorePath = cmd.getOptionValue(OPT_KEYSTORE,
                "../too-many-secrets/littleproxy_keystore.jks");
        this.expectedAuthToken = cmd.getOptionValue(OPT_AUTHTOKEN,
                "534#^#$523590)");
        this.instanceId = cmd.getOptionValue(OPT_INSTANCE_ID);
        if (cmd.hasOption(OPT_PT)) {
            initPluggableTransport(cmd
                    .getOptionProperties(Cli.OPTION_PLUGGABLE_TRANSPORT));
        }
    }

    private void initPluggableTransport(Properties props) {
        String type = props.getProperty("type");
        if (type != null) {
            PtType proxyPtType = PtType.valueOf(type.toUpperCase());
            pt = PluggableTransports.newTransport(
                    proxyPtType,
                    props);
            LOGGER.info("Using pluggable transport of type {} ", proxyPtType);
        }
    }

    public void start() {
        LOGGER.info(String
                .format("Starting Give proxy with the following settings ...\n"
                        +
                        "Host: %1$s\n" +
                        "HTTP port: %2$s\n" +
                        "HTTPS port: %3$s\n" +
                        "UDT port: %4$s\n" +
                        "Keystore path: %5$s\n" +
                        "Auth token: %6$s\n" +
                        "Instance Id: %7$s\n",
                        host,
                        httpPort,
                        httpsPort,
                        udtPort,
                        keyStorePath,
                        expectedAuthToken,
                        instanceId));
        startTcp();
        if (udtPort != null) {
            startUdt();
        }
        if (instanceId != null) {
            startStats();
        }
    }

    protected void initializeCliOptions() {
        //@formatter:off
        addOption(new Option(OPT_HOST, true, "(Required) The proxy's public hostname or ip address"), true);
        addOption(new Option(OPT_HTTP_PORT, true, "HTTP listen port.  Defaults to 80."), false);
        addOption(new Option(OPT_HTTPS_PORT, true, "HTTPS listen port.  Defaults to 443."), false);
        addOption(new Option(OPT_UDT_PORT, true, "UDT listen port.  If not specified, proxy does not listen for UDT connections."), false);
        addOption(new Option(OPT_KEYSTORE, true, "Path to keystore containing proxy's cert.  Defaults to ../too-many-secrets/littleproxy_keystore.jks"), false);
        addOption(new Option(OPT_AUTHTOKEN, true, "Auth token that this proxy requires from its clients.  Defaults to '534#^#$523590)'."), false);
        addOption(new Option(OPT_INSTANCE_ID, true, "The instanceid.  If specified, stats will be reported under this instance id.  Otherwise, stats will not be reported."), false);
        options.addOption(OptionBuilder
                .withLongOpt(OPT_PT)
                .withArgName("property=value")
                .hasArgs(2)
                .withValueSeparator()
                .withDescription("(Optional) Specify pluggable transport properties")
                .create());
        //@formatter:on
    }

    private void startTcp() {
        LOGGER.info("Starting Plain Text Give proxy at TCP port {}", httpPort);
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
                .plusActivityTracker(activityTracker)
                .start();

        int serverPort = httpsPort;
        boolean allowLocalOnly = false;
        boolean encryptionRequired = true;
        if (pt != null) {
            // When using a pluggable transport, the transport will use the
            // configured port and the server will use some random free port
            // that only allows local connections
            serverPort = LanternUtils.findFreePort();
            allowLocalOnly = true;
            encryptionRequired = !pt.suppliesEncryption();
        }

        LOGGER.info(
                "Starting TLS Give proxy at TCP port {}", httpsPort);
        HttpProxyServerBootstrap bootstrap = DefaultHttpProxyServer.bootstrap()
                .withName("Give-Encrypted")
                .withPort(serverPort)
                .withAllowLocalOnly(allowLocalOnly)
                .withListenOnAllAddresses(true)
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
                .plusActivityTracker(activityTracker);

        if (encryptionRequired) {
            bootstrap.withSslEngineSource(
                    new SimpleSslEngineSource(keyStorePath));
        }

        server = bootstrap.start();

        if (pt != null) {
            LOGGER.info("Starting PluggableTransport");
            InetSocketAddress giveModeAddress = server.getListenAddress();
            pt.startServer(httpsPort, giveModeAddress);
        }
    }

    private void startUdt() {
        LOGGER.info("Starting Give proxy at UDT port {}", udtPort);
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

    private void startStats() {
        LOGGER.info(
                "Starting to report stats to statshub under instanceid: {}",
                instanceId);
        statsScheduler.scheduleAtFixedRate(
                postStats,
                10,
                StatsManager.FALLBACK_POST_INTERVAL,
                TimeUnit.SECONDS);
    }

    private Runnable postStats = new Runnable() {
        @Override
        public void run() {
            try {
                Stats instanceStats = stats.toInstanceStats();
                StatsManager.addSystemStats(instanceStats);
                statshub.postInstanceStats(
                        instanceId,
                        null,
                        StatsManager.UNKNOWN_COUNTRY,
                        true,
                        instanceStats);
            } catch (Exception e) {
                LOGGER.warn("Unable to post stats to statshub: {}",
                        e.getMessage(), e);
            }
        }
    };
}
