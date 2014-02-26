package org.lantern.proxy.pt;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecuteResultHandler;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.ExecuteWatchdog;
import org.apache.commons.exec.Executor;
import org.apache.commons.exec.PumpStreamHandler;
import org.apache.commons.exec.ShutdownHookProcessDestroyer;
import org.lantern.JsonUtils;
import org.lantern.LanternUtils;
import org.littleshoot.util.NetworkUtils;
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
public class FTE implements PluggableTransport {
    private static final Logger LOGGER = LoggerFactory.getLogger(FTE.class);
    private static final String FTE_BASE_PATH = "pt/fteproxy";
    private static final String[] FTE_EXECUTABLE_NAMES =
            new String[] { "fteproxy", "fteproxy.exe" };
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
    private String ftePath;
    private CommandLine cmd;
    private Executor cmdExec;
    private boolean useCustomFormat;

    /**
     * Construct a new FTE pluggable transport using the given configuration
     * props.
     * 
     * @param props
     */
    public FTE(Properties props) {
        super();
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
    }

    @Override
    public InetSocketAddress startClient(
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress) {
        LOGGER.info("Starting FTE client");
        InetSocketAddress address = new InetSocketAddress(
                getModeAddress.getAddress(),
                LanternUtils.findFreePort());

        startFteProxy(
                "--mode", "client",
                "--client_port", address.getPort(),
                "--server_ip", proxyAddress.getAddress().getHostAddress(),
                "--server_port", proxyAddress.getPort());

        if (!LanternUtils.waitForServer(address, 60000)) {
            throw new RuntimeException("Unable to start FTE client");
        }

        return address;
    }

    @Override
    public void stopClient() {
        LOGGER.info("Stopping FTE client");
        cmdExec.getWatchdog().destroyProcess();
    }

    @Override
    public void startServer(int port, InetSocketAddress giveModeAddress) {
        LOGGER.info("Starting FTE server");

        try {
            String ip = NetworkUtils.getLocalHost().getHostAddress();

            startFteProxy(
                    "--mode", "server",
                    "--server_ip", ip,
                    "--server_port", port,
                    "--proxy_ip",
                    giveModeAddress.getAddress().getHostAddress(),
                    "--proxy_port", giveModeAddress.getPort());
        } catch (UnknownHostException uhe) {
            throw new RuntimeException("Unable to determine interface ip: "
                    + uhe.getMessage(), uhe);
        }
        if (!LanternUtils.waitForServer(port, 60000)) {
            throw new RuntimeException("Unable to start FTE server");
        }
    }

    @Override
    public void stopServer() {
        LOGGER.info("Stopping FTE server");
        cmdExec.getWatchdog().destroyProcess();
    }

    @Override
    public boolean suppliesEncryption() {
        return true;
    }

    private void startFteProxy(Object... args) {
        initFtePath();
        updateCustomFormatsIfNecessary();
        buildCmdLine(args);
        exec();
    }

    private void initFtePath() {
        File fte = null;
        for (String name : FTE_EXECUTABLE_NAMES) {
            fte = new File(FTE_BASE_PATH + "/" + name);
            ftePath = fte.getAbsolutePath();
            if (fte.exists()) {
                break;
            } else {
                LOGGER.info("fteproxy executable not found at {}", ftePath);
                fte = null;
                ftePath = null;
            }
        }
        if (fte == null) {
            String message = "fteproxy executable not found in search path";
            LOGGER.error(message, ftePath);
            throw new Error(message);
        }
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
                    FTE_BASE_PATH, LANTERN_DEFS_RELEASE);
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

    private void buildCmdLine(Object... args) {
        cmd = new CommandLine(ftePath);
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
        for (Object arg : args) {
            cmd.addArgument(stringify(arg));
        }
    }

    private void exec() {
        cmdExec = new DefaultExecutor();
        cmdExec.setStreamHandler(new PumpStreamHandler(System.out,
                System.err,
                System.in));
        cmdExec.setProcessDestroyer(new ShutdownHookProcessDestroyer());
        cmdExec.setWatchdog(new ExecuteWatchdog(
                ExecuteWatchdog.INFINITE_TIMEOUT));
        DefaultExecuteResultHandler resultHandler = new DefaultExecuteResultHandler();
        LOGGER.info("About to run cmd: {}", cmd);
        try {
            cmdExec.execute(cmd, resultHandler);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static String stringify(Object value) {
        return String.format("%1$s", value);
    }
}
