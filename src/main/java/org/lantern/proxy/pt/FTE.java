package org.lantern.proxy.pt;

import java.io.File;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.util.Properties;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecuteResultHandler;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.ExecuteWatchdog;
import org.apache.commons.exec.Executor;
import org.apache.commons.exec.LogOutputStream;
import org.apache.commons.exec.PumpStreamHandler;
import org.apache.commons.exec.ShutdownHookProcessDestroyer;
import org.lantern.LanternUtils;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class FTE implements PluggableTransport {
    private static final Logger LOGGER = LoggerFactory.getLogger(FTE.class);
    private static final String DEFAULT_FTE_PATH = "pt/fteproxy";
    private static final String FTE_PATH_KEY = "path";
    private static final String FTE_KEY_KEY = "key";

    private Executor client;
    private Executor server;
    private Properties props;

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

        client = fteProxy(
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
        client.getWatchdog().destroyProcess();
    }

    @Override
    public void startServer(int port, InetSocketAddress giveModeAddress) {
        LOGGER.info("Starting FTE server");

        try {
            String ip = NetworkUtils.getLocalHost().getHostAddress();

            server = fteProxy(
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
        server.getWatchdog().destroyProcess();
    }

    @Override
    public boolean suppliesEncryption() {
        return true;
    }

    private Executor fteProxy(Object... args) {
        Executor cmdExec = new DefaultExecutor();
        cmdExec.setStreamHandler(new PumpStreamHandler(System.out,
                System.err,
                System.in));
        cmdExec.setProcessDestroyer(new ShutdownHookProcessDestroyer());
        cmdExec.setWatchdog(new ExecuteWatchdog(
                ExecuteWatchdog.INFINITE_TIMEOUT));
        cmdExec.setStreamHandler(new PumpStreamHandler(new LogOutputStream() {
            @Override
            protected void processLine(String line, int level) {
                LOGGER.debug("(From fteproxy): {}", line);
            }
        }));
        String ftePath = props.getProperty(FTE_PATH_KEY, DEFAULT_FTE_PATH);
        File fte = new File(ftePath + "/fteproxy");
        ftePath = fte.getAbsolutePath();
        if (!fte.exists()) {
            String message = String.format(
                    "fteproxy executable not found at %1$s", ftePath);
            LOGGER.error(String.format("fteproxy executable not found at %1$s",
                    ftePath));
            throw new Error(message);
        }
        CommandLine cmd = new CommandLine(ftePath);
        // If a key was configured, set it
        String key = props.getProperty(FTE_KEY_KEY);
        if (key != null) {
            cmd.addArgument("--key");
            cmd.addArgument(stringify(key));
        }
        for (Object arg : args) {
            cmd.addArgument(stringify(arg));
        }
        DefaultExecuteResultHandler resultHandler = new DefaultExecuteResultHandler();
        LOGGER.info("About to run cmd: {}", cmd);
        try {
            cmdExec.execute(cmd, resultHandler);
            return cmdExec;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static String stringify(Object value) {
        return String.format("%1$s", value);
    }
}
