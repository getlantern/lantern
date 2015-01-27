package org.lantern.proxy.pt;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpDelete;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.util.EntityUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.Launcher;
import org.lantern.event.AutoReportChangedEvent;
import org.lantern.event.Events;
import org.lantern.event.WaddellPeerAvailabilityEvent;
import org.lantern.geoip.GeoData;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.proxy.FallbackProxy;
import org.lantern.state.Model;
import org.lantern.util.ProcessUtil;
import org.lantern.util.PublicIpAddress;
import org.lantern.util.StaticHttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.yaml.snakeyaml.DumperOptions;
import org.yaml.snakeyaml.Yaml;

import com.google.common.eventbus.Subscribe;

/**
 * <p>
 * Implementation of {@link PluggableTransport} that runs a standalone
 * flashlight process in order to provide a client pluggable transport. It
 * cannot be used as a server-side pluggable transport.
 * </p>
 */
public class Flashlight extends BasePluggableTransport {
    private static final Logger LOGGER = LoggerFactory
            .getLogger(Flashlight.class);
    private static final File CA_CERT_FILE =
            new File(LanternClientConstants.CONFIG_DIR + File.separator +
                    "pt" + File.separator +
                    "flashlight" + File.separator +
                    "cacert.pem");
    private static final String STATS_PATH = "/Stats";

    public static final String ADDRESS_KEY = "addr";
    public static final String SERVER_KEY = "server";
    public static final String MASQUERADE_KEY = "masquerade";
    public static final String PORTMAP_KEY = "portmap";
    public static final String CLOUDCONFIG_KEY = "cloudconfig";
    public static final String CLOUDCONFIG_CA_KEY = "cloudconfigca";
    public static final String WADDELL_ADDR_KEY = "waddelladdr";

    public static final String CLIENT_STATS_ADDR = "127.0.0.1:15670";
    public static final String SERVER_STATS_ADDR = "127.0.0.1:15671";
    public static final String X_FLASHLIGHT_QOS = "X-Flashlight-QOS";
    public static final int HIGH_QOS = 10;

    private static final Pattern WADDELL_ID_PATTERN = Pattern
            .compile("^.*Connected to Waddell!! Id is: (.*)$");
    private static final String CLIENT_PATH = "/Client";
    private static final String PEERS_PATH = "/Client/Peers";
    private static final String CHAINED_PATH = "/Client/ChainedServers";

    private final Properties props;
    private final String configAddr;
    private final AtomicBoolean isClient = new AtomicBoolean();

    /**
     * Construct a new Flashlight pluggable transport.
     * 
     * @param props
     *            ignored
     * @param masquerade
     *            The class for determining the flashlight masquerade host to
     *            use. This is passed because determining the masquerade
     *            requires the network to be up and is fairly intensive, so we
     *            only want to do it at the last minute when we're running
     *            flashlight, in which case the network should also be up, and
     *            we know we really need to determine the masquerade host to
     *            use.
     */
    public Flashlight(Properties props) {
        super(false, "pt/flashlight", "flashlight");
        this.props = props;
        // Pick a random address for listening for config updates
        this.configAddr = String.format("localhost:%s",
                LanternUtils.randomPort());
        Events.register(this);
    }

    private static String getClientConfigDir() {
        return String.format("%s%spt%sflashlight",
                LanternClientConstants.CONFIG_DIR,
                File.separatorChar,
                File.separatorChar);
    }

    private static String getServerConfigDir() {
        return String.format("%s%spt%sflashlight-server",
                LanternClientConstants.CONFIG_DIR,
                File.separatorChar,
                File.separatorChar);
    }
    
    public void startStandaloneClient() {
        cmd = new CommandLine(this.exe);
        
        addClientArgs(cmd, LanternConstants.LANTERN_LOCALHOST_ADDR, null, null);
        exec();

        if (!LanternUtils.waitForServer(LanternConstants.LANTERN_LOCALHOST_ADDR, 60000)) {
            throw new RuntimeException(String.format("Unable to start %1$s",
                    getLogName()));
        }
    }

    @Override
    protected void addClientArgs(CommandLine cmd,
            InetSocketAddress listenAddress,
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress) {
        isClient.set(true);

        addCommonArgs(cmd);

        cmd.addArgument("-role");
        cmd.addArgument("client");

        cmd.addArgument("-configdir");
        cmd.addArgument(getClientConfigDir());

        cmd.addArgument("-addr");
        cmd.addArgument(String.format("%s:%s", listenAddress.getHostName(),
                listenAddress.getPort()));
        
        cmd.addArgument("-statsaddr");
        cmd.addArgument(CLIENT_STATS_ADDR);

        cmd.addArgument("-cloudconfig");
        cmd.addArgument(props.getProperty(CLOUDCONFIG_KEY));

        cmd.addArgument("-cloudconfigca");
        cmd.addArgument(props.getProperty(CLOUDCONFIG_CA_KEY), false);

        addCommonArgs(cmd);
    }

    @Override
    protected void addServerArgs(
            CommandLine cmd,
            String ip__ignore,
            int listenPort,
            InetSocketAddress address__ignore) {
        addCommonArgs(cmd);

        cmd.addArgument("-role");
        cmd.addArgument("server");

        cmd.addArgument("-server");
        cmd.addArgument(props.getProperty(SERVER_KEY));

        cmd.addArgument("-configdir");
        cmd.addArgument(getServerConfigDir());

        cmd.addArgument("-addr");
        cmd.addArgument(":" + listenPort);

        cmd.addArgument("-statsaddr");
        cmd.addArgument(SERVER_STATS_ADDR);

        String portmap = props.getProperty(PORTMAP_KEY);
        if (portmap != null) {
            cmd.addArgument("-portmap");
            cmd.addArgument(portmap);
        }

        String waddellAddr = props.getProperty(WADDELL_ADDR_KEY);
        if (waddellAddr != null) {
            cmd.addArgument("-waddelladdr");
            cmd.addArgument(waddellAddr);
        }

        addCommonArgs(cmd);
    }

    private void addCommonArgs(CommandLine cmd) {
        addParentPIDIfAvailable(cmd);

        cmd.addArgument("-configaddr");
        cmd.addArgument(configAddr);

        if (Launcher.getInstance() != null) {
            Model model = Launcher.getInstance().getModel();
            String period = "0";
            if (model.getSettings().isAutoReport()) {
                period = "300"; // five minutes
            }

            cmd.addArgument("-statsperiod");
            cmd.addArgument(period);

            cmd.addArgument("-instanceid");
            cmd.addArgument(model.getInstanceId());

            String ipAddress = new PublicIpAddress().getPublicIpAddress()
                    .getHostAddress();
            GeoData geoData = Launcher.getInstance()
                    .lookup(GeoIpLookupService.class).getGeoData(ipAddress);
            cmd.addArgument("-country");
            cmd.addArgument(geoData.getCountry().getIsoCode());
        }
    }

    /**
     * We do this to let the Windows version of flashlight know Lantern's PID so
     * that it can terminate itself in case Lantern dies unexpectedly.
     * 
     * @param cmd
     */
    private void addParentPIDIfAvailable(CommandLine cmd) {
        try {
            final int myPID = ProcessUtil.getMyPID();
            cmd.addArgument("-parentpid");
            cmd.addArgument(String.valueOf(myPID));
        } catch (IOException e) {
            LOGGER.error("Could not determine PID!", e);
        }

    }

    @Override
    public boolean suppliesEncryption() {
        return true;
    }

    @Override
    public String getLocalCACert() {
        try {
            return FileUtils.readFileToString(CA_CERT_FILE);
        } catch (IOException ioe) {
            throw new RuntimeException("Unable to read cacert.pem: "
                    + ioe.getMessage(), ioe);
        }
    }

    @Override
    protected LoggingStreamHandler buildLoggingStreamHandler(
            final Logger logger,
            InputStream is) {
        return new LoggingStreamHandler(logger, is) {
            @Override
            protected void handleLine(String line, boolean logToError) {
                Matcher matcher = WADDELL_ID_PATTERN.matcher(line);
                if (matcher.matches()) {
                    String id = matcher.group(1);
                    String waddellAddr = props.getProperty(WADDELL_ADDR_KEY);
                    if (waddellAddr != null) {
                        // We're a server, raise the ConnectedToWaddellEvent
                        logger.info(
                                "Connected to waddell {} with id {}, posting ConnectedToWaddellEvent",
                                waddellAddr, id);
                        Events.asyncEventBus().post(
                                new ConnectedToWaddellEvent(id, waddellAddr));
                    }
                }
                super.handleLine(line, logToError);
            }
        };
    }

    @Subscribe
    public void onAutoReportChanged(final AutoReportChangedEvent event) {
        LOGGER.debug("Received AutoReportChangedEvent: {}", event);
        toggleStatsReporting(event.isAutoReport());
    }

    private void toggleStatsReporting(boolean autoReport) {
        String reportingPeriod = "0";
        String enableDisable = "disable";
        if (autoReport) {
            reportingPeriod = "5m0s";
            enableDisable = "enable";
        }
        Map<String, Object> stats = new HashMap<String, Object>();
        stats.put("reportingperiod", reportingPeriod);
        try {
            postConfig(STATS_PATH, stats);
            LOGGER.info("{}d stats reporting", enableDisable);
        } catch (Exception e) {
            LOGGER.warn("Unable to {} stats reporting: {}", enableDisable,
                    e.getMessage(), e);
        }
    }

    @Subscribe
    public void onWaddellPeerAvailability(WaddellPeerAvailabilityEvent event) {
        if (isClient.get()) {
            if (event.isAvailable()) {
                addWaddellPeer(event.getEncryptedJid(),
                        event.getId(),
                        event.getWaddellAddr(),
                        event.getCountry());
            } else {
                removeWaddellPeer(event.getEncryptedJid());
            }
        }
    }
    
    public void addFallbackProxies(Collection<FallbackProxy> fallbacks) {
        if (fallbacks.size() == 0) {
            return;
        }
        Map<String, Map<String, Object>> config = new HashMap<String, Map<String,Object>>();
        for (FallbackProxy fallback : fallbacks) {
            Map<String, Object> proxy = new HashMap<String, Object>();
            proxy.put("addr", fallback.getWanHost() + ":" + fallback.getWanPort());
            proxy.put("cert", fallback.getCert());
            proxy.put("authtoken", fallback.getAuthToken());
            // Set really high priority
            int domainFrontedPriority = 4000;
            proxy.put("weight", domainFrontedPriority * 100);
            // Set high QOS
            proxy.put("qos", Flashlight.HIGH_QOS);
            config.put("fallback-" + fallback.getWanHost(), proxy);
        }
        try {
            postConfig(CHAINED_PATH, config);
            LOGGER.info("Set {} fallback proxies in flashlight", fallbacks.size());
        } catch (Exception e) {
            LOGGER.error("Unable to set fallback proxies in flashlight: {}", e.getMessage(), e);
        }
    }

    /**
     * Adds a waddell peer to flashlight's configuration.
     * 
     * @param encryptedJid
     * @param id
     * @param waddellAddr
     * @param country
     */
    private void addWaddellPeer(String encryptedJid, String id,
            String waddellAddr, String country) {
        try {
            Map<String, Object> peer = new HashMap<String, Object>();
            peer.put("id", id);
            peer.put("waddelladdr", waddellAddr);
            Map<String, Object> extras = new HashMap<String, Object>();
            extras.put("country", country);
            peer.put("extras", extras);
            Map<String, Object> peers = new HashMap<String, Object>();
            peers.put(encryptedJid, peer);
            postConfig(PEERS_PATH, peers);
            LOGGER.debug("Added waddell peer {} with id {} at {}",
                    encryptedJid, id, waddellAddr);
        } catch (Exception e) {
            LOGGER.error("Unable to add waddell peer: {}", e.getMessage(), e);
        }
    }

    /**
     * Removes a waddel peer from flashlight's configuration
     * 
     * @param encryptedJid
     */
    private void removeWaddellPeer(String encryptedJid) {
        try {
            deleteConfig(PEERS_PATH + "/" + encryptedJid);
            LOGGER.debug("Deleted waddell peer with id {}", encryptedJid);
        } catch (Exception e) {
            LOGGER.error("Unable to delete waddell peer: {}", e.getMessage(), e);
        }
    }
    
    public void setMinQOS(int qos) {
        LOGGER.info("Setting minimum QOS to {}", qos);
        Map<String, Object> client = new HashMap<String, Object>();
        client.put("minqos", qos);
        try {
            postConfig(CLIENT_PATH, client);
            LOGGER.info("Set minimum QOS to {}", qos);
        } catch (Exception e) {
            LOGGER.error("Unable to set minimum QOS to {}: {}", qos, e.getMessage(), e);
        }
    }

    private void postConfig(String path, Map<String, ?> data) throws Exception {
        DumperOptions options = new DumperOptions();
        options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK);
        options.setDefaultScalarStyle(DumperOptions.ScalarStyle.DOUBLE_QUOTED);
        postConfig(path, new Yaml(options).dump(data));
    }

    private void postConfig(String path, String data) throws Exception {
        HttpPost post = new HttpPost(configUrl(path));
        post.setHeader("Content-Type", "application/yaml");
        HttpEntity requestEntity = new StringEntity(data, "UTF-8");
        post.setEntity(requestEntity);
        HttpClient client = StaticHttpClientFactory.newDirectClient();
        HttpResponse response = client.execute(post);
        checkFlashlightConfigResponse(response);
    }

    private void deleteConfig(String path) throws Exception {
        HttpDelete delete = new HttpDelete(configUrl(path));
        HttpClient client = StaticHttpClientFactory.newDirectClient();
        HttpResponse response = client.execute(delete);
        checkFlashlightConfigResponse(response);
    }

    private String configUrl(String path) {
        return "http://" + configAddr + "/" + path;
    }

    private void checkFlashlightConfigResponse(HttpResponse response)
            throws Exception {
        final HttpEntity entity = response.getEntity();
        String body = IOUtils.toString(entity.getContent(), "UTF-8");
        EntityUtils.consume(entity);
        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode != 200) {
            throw new RuntimeException(String.format(
                    "Error posting. Status code:%1$s, body: %2$s",
                    statusCode, body));
        }
    }
}
