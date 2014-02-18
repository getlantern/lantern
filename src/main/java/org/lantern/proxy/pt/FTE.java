package org.lantern.proxy.pt;

import java.io.File;
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

public class FTE implements PluggableTransport {
    private static final Logger LOGGER = LoggerFactory.getLogger(FTE.class);
    private static final String FTE_BASE_PATH = "pt/fteproxy";
    private static final String LANTERN_DEFS_RELEASE = "19700101";
    // Note - I'm using the default format names here because of this bug:
    // https://github.com/kpdyer/fteproxy/issues/117
    private static final String LANTERN_UPSTREAM_FORMAT_KEY = "manual-http-request";
    private static final String LANTERN_DOWNSTREAM_FORMAT_KEY = "manual-http-response";
    private static final String FTE_UPSTREAM_REGEX_KEY = "upstream_regex";
    private static final String FTE_UPSTREAM_FIXED_SLICE_KEY = "upstream_fixed_slice";
    private static final String FTE_DOWNSTREAM_REGEX_KEY = "downstream_regex";
    private static final String FTE_DOWNSTREAM_FIXED_SLICE_KEY = "downstream_fixed_slice";
    private static final String FTE_KEY_KEY = "key";

    private Properties props;
    private String ftePath;
    private CommandLine cmd;
    private Executor cmdExec;
    private boolean useCustomFormat;

    public FTE(Properties props) {
        super();
        this.props = props;
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
        File fte = new File(FTE_BASE_PATH + "/fteproxy");
        ftePath = fte.getAbsolutePath();
        if (!fte.exists()) {
            String message = String.format(
                    "fteproxy executable not found at %1$s", ftePath);
            LOGGER.error(String.format("fteproxy executable not found at %1$s",
                    ftePath));
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

        String upstreamRegex = props.getProperty(FTE_UPSTREAM_REGEX_KEY);
        String downstreamRegex = props.getProperty(FTE_DOWNSTREAM_REGEX_KEY);

        if (upstreamRegex != null || downstreamRegex != null) {
            if (upstreamRegex == null || downstreamRegex == null) {
                LOGGER.error("Need to specify both a downstream-regex and an upstream-regex, falling back to standard regexes");
                return;
            }
            Map<String, Object> upstreamDef = buildDef(upstreamRegex,
                    props.getProperty(FTE_UPSTREAM_FIXED_SLICE_KEY));
            defs.put(LANTERN_UPSTREAM_FORMAT_KEY, upstreamDef);
            Map<String, Object> downstreamDef = buildDef(downstreamRegex,
                    props.getProperty(FTE_DOWNSTREAM_FIXED_SLICE_KEY));
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
        String key = props.getProperty(FTE_KEY_KEY);
        if (key != null) {
            cmd.addArgument("--key");
            cmd.addArgument(stringify(key));
        }
        if (useCustomFormat) {
            cmd.addArgument("--release");
            cmd.addArgument(LANTERN_DEFS_RELEASE);
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
