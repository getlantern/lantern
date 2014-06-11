package org.lantern.proxy.pt;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Properties;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.io.FileUtils;
import org.lantern.LanternClientConstants;

/**
 * <p>
 * Implementation of {@link PluggableTransport} that runs a standalone
 * flashlight process in order to provide a client pluggable transport. It
 * cannot be used as a server-side pluggable transport.
 * </p>
 */
public class Flashlight extends BasePluggableTransport {
    private static final File CA_CERT_FILE =
            new File(LanternClientConstants.CONFIG_DIR + File.separator +
                    "pt" + File.separator +
                    "flashlight" + File.separator +
                    "cacert.pem");

    public static final String ADDRESS_KEY = "addr";
    public static final String SERVER_KEY = "server";
    public static final String MASQUERADE_KEY = "masquerade";
    public static final String ROOT_CA_KEY = "rootca";
    
    private final Properties props;

    /**
     * Construct a new Flashlight pluggable transport.
     * 
     * @param props
     *            ignored
     */
    public Flashlight(Properties props) {
        super(false,
                "pt/flashlight",
                "flashlight", "flashlight.exe");
        this.props = props;
    }

    @Override
    protected void addClientArgs(CommandLine cmd,
            InetSocketAddress listenAddress,
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress) {
        cmd.addArgument("-role");
        cmd.addArgument("client");
        
        cmd.addArgument("-server");
        cmd.addArgument(props.getProperty(SERVER_KEY));
        
        cmd.addArgument("-masquerade");
        cmd.addArgument(props.getProperty(MASQUERADE_KEY));

        cmd.addArgument("-rootca");
        cmd.addArgument(props.getProperty(ROOT_CA_KEY), false);

        cmd.addArgument("-configdir");
        cmd.addArgument(String.format("%s%spt%sflashlight",
                LanternClientConstants.CONFIG_DIR,
                File.separatorChar,
                File.separatorChar));

        cmd.addArgument("-addr");
        cmd.addArgument(String.format("%s:%s", listenAddress.getHostName(),
                listenAddress.getPort()));
    }

    @Override
    protected void addServerArgs(CommandLine cmd, String listenIp,
            int listenPort, InetSocketAddress giveModeAddress) {
        throw new UnsupportedOperationException(
                "flashlight does not support server mode");
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
