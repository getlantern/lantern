package org.lantern.proxy.pt;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

import org.apache.commons.exec.CommandLine;
import org.lantern.JsonUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * <p>
 * Implementation of {@link PluggableTransport} that runs a standalone fteproxy
 * process in order to provide either the client or server pluggable transport.
 * </p>
 * 
 * <p>
 * The following configuration properties are supported:
 * </p>
 * 
 * <ul>
 * <li>upstream-regex : custom regex to use from client to server (e.g. for the
 * HTTP request)</li>
 * <li>upstream-fixed-slice : custom fixed slice size to use for upstream regex
 * (defaults to 256)</li>
 * <li>downstream-regex : custom regex to use from server to client (e.g. for
 * the HTTP response)</li>
 * <li>downstream-fixed-slice : custom fixed slice size to use for downstream
 * regex (defaults to 256)</li>
 * <li>key : custom crypto key to use (must be 64 bits)</li>
 * <li>file : path to a file from which configuration properties will be read.
 * Any properties specified explicitly at the command-line override whatever has
 * been set in the file.</li>
 * </ul>
 */
public class FTE extends BasePluggableTransport {
    private static final Logger LOGGER = LoggerFactory.getLogger(FTE.class);

    private static final String LANTERN_DEFS_RELEASE = "19700101";
    // Note - custom format names need to end with "-request" and "-response"
    // respectively, otherwise fteproxy won't recognize them.
    private static final String LANTERN_UPSTREAM_FORMAT_KEY = "lantern-request";
    private static final String LANTERN_DOWNSTREAM_FORMAT_KEY = "lantern-response";

    public static final String UPSTREAM_REGEX_KEY = "upstream-regex";
    public static final String UPSTREAM_FIXED_SLICE_KEY = "upstream-fixed-slice";
    public static final String DOWNSTREAM_REGEX_KEY = "downstream-regex";
    public static final String DOWNSTREAM_FIXED_SLICE_KEY = "downstream-fixed-slice";
    public static final String KEY_KEY = "key";

    private Properties props;
    private boolean useCustomFormat;

    /**
     * Construct a new FTE pluggable transport using the given configuration
     * props.
     * 
     * @param props
     */
    public FTE(Properties props) {
        super(true, "pt/fteproxy", "fteproxy");
        this.props = props;
        String propsFile = props.getProperty("file");
        if (propsFile != null) {
            try {
                InputStream in = new FileInputStream(propsFile);
                try {
                    this.props.load(in);
                } finally {
                    try {
                        in.close();
                    } catch (IOException ioe) {
                        // ignore
                    }
                }
            } catch (IOException ioe) {
                throw new RuntimeException(
                        String.format(
                                "Unable to initialize FTE from properties file %1$s: %2$s",
                                propsFile, ioe.getMessage()), ioe);
            }
        }
        updateCustomFormatsIfNecessary();
    }

    @Override
    protected void addClientArgs(CommandLine cmd,
            InetSocketAddress listenAddress,
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress) {
        addCommonArgs(cmd);

        cmd.addArgument("--mode");
        cmd.addArgument("client");

        cmd.addArgument("--client_port");
        cmd.addArgument(stringify(listenAddress.getPort()));

        cmd.addArgument("--server_ip");
        cmd.addArgument(proxyAddress.getAddress().getHostAddress());

        cmd.addArgument("--server_port");
        cmd.addArgument(stringify(proxyAddress.getPort()));
    }

    @Override
    protected void addServerArgs(CommandLine cmd, String listenIp,
            int listenPort, InetSocketAddress giveModeAddress) {
        addCommonArgs(cmd);

        cmd.addArgument("--mode");
        cmd.addArgument("server");

        cmd.addArgument("--server_ip");
        cmd.addArgument(stringify(listenIp));

        cmd.addArgument("--server_port");
        cmd.addArgument(stringify(listenPort));

        cmd.addArgument("--proxy_ip");
        cmd.addArgument(giveModeAddress.getAddress().getHostAddress());

        cmd.addArgument("--proxy_port");
        cmd.addArgument(stringify(giveModeAddress.getPort()));
    }

    private void addCommonArgs(CommandLine cmd) {
        // If a key was configured, set it
        String key = props.getProperty(KEY_KEY);
        if (key != null) {
            cmd.addArgument("--key");
            cmd.addArgument(stringify(key));
        }
        if (useCustomFormat) {
            cmd.addArgument("--release");
            cmd.addArgument(LANTERN_DEFS_RELEASE);
            cmd.addArgument("--upstream-format");
            cmd.addArgument(LANTERN_UPSTREAM_FORMAT_KEY);
            cmd.addArgument("--downstream-format");
            cmd.addArgument(LANTERN_DOWNSTREAM_FORMAT_KEY);
        }
    }

    @Override
    public boolean suppliesEncryption() {
        return true;
    }

    @Override
    public String getLocalCACert() {
        return null;
    }

    /**
     * If the props contain a custom regex for the upstream or the downstream
     * format, we create a special defs file "19700101.json" that contains the
     * custom regexes (and optional fixed slices) for our custom formats. These
     * formats are keyed "lantern_upstream" and "lantern_downstream"
     * respectively.
     */
    private void updateCustomFormatsIfNecessary() {
        Map<String, Object> defs = new HashMap<String, Object>();

        String upstreamRegex = props.getProperty(UPSTREAM_REGEX_KEY);
        String downstreamRegex = props.getProperty(DOWNSTREAM_REGEX_KEY);

        if (upstreamRegex != null || downstreamRegex != null) {
            if (upstreamRegex == null || downstreamRegex == null) {
                LOGGER.error("Need to specify both a downstream-regex and an upstream-regex, falling back to standard regexes");
                return;
            }
            Map<String, Object> upstreamDef = buildDef(upstreamRegex,
                    props.getProperty(UPSTREAM_FIXED_SLICE_KEY));
            defs.put(LANTERN_UPSTREAM_FORMAT_KEY, upstreamDef);
            Map<String, Object> downstreamDef = buildDef(downstreamRegex,
                    props.getProperty(DOWNSTREAM_FIXED_SLICE_KEY));
            defs.put(LANTERN_DOWNSTREAM_FORMAT_KEY, downstreamDef);
            String defsFilePath = String.format("%1$s/fte/defs/%2$s.json",
                    ptBasePath, LANTERN_DEFS_RELEASE);
            try {
                JsonUtils.OBJECT_MAPPER
                        .writeValue(new File(defsFilePath), defs);
                useCustomFormat = true;
            } catch (Exception e) {
                LOGGER.error(
                        "Unable to write defs file with custom regex, falling back to standard regexes: "
                                + e.getMessage(), e);
            }
        }
    }

    private Map<String, Object> buildDef(String regex, String fixedSlice) {
        Map<String, Object> def = new HashMap<String, Object>();
        def.put("regex", regex);
        if (fixedSlice != null) {
            def.put("fixedSlice", fixedSlice);
        }
        return def;
    }
}
