package org.lantern.proxy.pt;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Properties;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.io.FileUtils;
import org.lantern.LanternClientConstants;
import org.lantern.util.ProcessUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * Implementation of {@link PluggableTransport} that runs a standalone
 * flashlight process in order to provide a client pluggable transport. It
 * cannot be used as a server-side pluggable transport.
 * </p>
 */
public class Flashlight extends BasePluggableTransport {
    
    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final File CA_CERT_FILE =
            new File(LanternClientConstants.CONFIG_DIR + File.separator +
                    "pt" + File.separator +
                    "flashlight" + File.separator +
                    "cacert.pem");

    public static final String ADDRESS_KEY = "addr";
    public static final String SERVER_KEY = "server";
    public static final String MASQUERADE_KEY = "masquerade";
    public static final String PORTMAP_KEY = "portmap";
    public static final String CLOUDCONFIG_KEY = "cloudconfig";
    public static final String CLOUDCONFIG_CA_KEY = "cloudconfigca";
    
    public static final String STATS_ADDR = "127.0.0.1:15670";
    public static final String X_FLASHLIGHT_QOS = "X-Flashlight-QOS";
    public static final String HIGH_QOS = "10";

    private final Properties props;

    /**
     * Construct a new Flashlight pluggable transport.
     * 
     * @param props ignored
     * @param masquerade The class for determining the flashlight masquerade
     * host to use. This is passed because determining the masquerade requires
     * the network to be up and is fairly intensive, so we only want to do it
     * at the last minute when we're running flashlight, in which case the
     * network should also be up, and we know we really need to determine
     * the masquerade host to use.
     */
    public Flashlight(Properties props) {
        super(false, "pt/flashlight", "flashlight");
        this.props = props;
    }

    @Override
    protected void addClientArgs(CommandLine cmd,
            InetSocketAddress listenAddress,
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress) {
        cmd.addArgument("-role");
        cmd.addArgument("client");

        cmd.addArgument("-configdir");
        cmd.addArgument(String.format("%s%spt%sflashlight",
                LanternClientConstants.CONFIG_DIR,
                File.separatorChar,
                File.separatorChar));

        cmd.addArgument("-addr");
        cmd.addArgument(String.format("%s:%s", listenAddress.getHostName(),
                listenAddress.getPort()));
        
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
        cmd.addArgument("-role");
        cmd.addArgument("server");

        cmd.addArgument("-server");
        cmd.addArgument(props.getProperty(SERVER_KEY));

        cmd.addArgument("-configdir");
        cmd.addArgument(String.format("%s%spt%sflashlight-server",
                LanternClientConstants.CONFIG_DIR,
                File.separatorChar,
                File.separatorChar));

        cmd.addArgument("-addr");
        cmd.addArgument(":" + listenPort);
        
        cmd.addArgument("-statsaddr");
        cmd.addArgument(STATS_ADDR);
        
        String portmap = props.getProperty(PORTMAP_KEY);
        if (portmap != null) {
            cmd.addArgument("-portmap");
            cmd.addArgument(portmap);
        }

        addCommonArgs(cmd);
    }
    
    private void addCommonArgs(CommandLine cmd) {
        // OX: temporarily disabling stats reporting for https://github.com/getlantern/lantern/issues/1943
//        cmd.addArgument("-statsperiod");
//        cmd.addArgument("300");
//        
//        cmd.addArgument("-instanceid");
//        cmd.addArgument(Launcher.getInstance().getModel().getInstanceId());
//        
//        String ipAddress = new PublicIpAddress().getPublicIpAddress().getHostAddress();
//        GeoData geoData = Launcher.getInstance().lookup(GeoIpLookupService.class).getGeoData(ipAddress);
//        cmd.addArgument("-country");
//        cmd.addArgument(geoData.getCountry().getIsoCode());
        
        addParentPIDIfAvailable(cmd);
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
            log.error("Could not determine PID!", e);
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

}
