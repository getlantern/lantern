package org.lantern.proxy.pt;

import java.io.File;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.util.HashSet;
import java.util.Set;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecuteResultHandler;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.ExecuteWatchdog;
import org.apache.commons.exec.Executor;
import org.apache.commons.exec.ShutdownHookProcessDestroyer;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.SystemUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Base class for PluggableTransports like Flashlight and FTEProxy that use
 * similar setups.
 */
public abstract class BasePluggableTransport implements PluggableTransport {
    private static final Logger LOGGER = LoggerFactory
            .getLogger(BasePluggableTransport.class);

    private static final Set<Class> ALREADY_COPIED_TRANSPORTS = new HashSet<Class>();

    private final String ptRelativePath;
    private final String[] executableNames;
    protected String ptBasePath;
    protected String ptPath;
    private CommandLine cmd;
    private Executor cmdExec;

    /**
     * Construct a new Flashlight pluggable transport.
     * 
     * @param copyToConfigFolder
     *            - if true, the pluggable transport will be copied to and run
     *            from the .lantern folder (necessary if the pluggable transport
     *            modifies files in its path)
     * @param relativePath
     *            - relative path of pluggable transports from its respective
     *            install folder
     * @param executableNames
     *            - all possible names under which the executable is found (e.g.
     *            with and without .exe extension)
     */
    protected BasePluggableTransport(boolean copyToConfigFolder,
            String relativePath,
            String... executableNames) {
        this.ptRelativePath = relativePath;
        this.executableNames = executableNames;
        this.ptBasePath = findBasePath().getAbsolutePath();
        if (copyToConfigFolder) {
            copyToConfigFolder();
        }
        initPtPath();
    }

    /**
     * Add the arguments for starting the client.
     * 
     * @param cmd
     * @param listenAddress
     *            address at which the pluggable transport should listen
     * @param getModeAddress
     * @param proxyAddress
     * @return
     */
    protected abstract void addClientArgs(CommandLine cmd,
            InetSocketAddress listenAddress,
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress);

    /**
     * Add the arguments for starting the server.
     * 
     * @param cmd
     * @param listenIp
     * @param listenPort
     * @param giveModeAddress
     * @return
     */
    protected abstract void addServerArgs(CommandLine cmd,
            String listenIp,
            int listenPort,
            InetSocketAddress giveModeAddress);

    @Override
    public InetSocketAddress startClient(
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress) {
        LOGGER.info("Starting {} client", getLogName());
        InetSocketAddress listenAddress = new InetSocketAddress(
                getModeAddress.getAddress(),
                LanternUtils.findFreePort());

        cmd = new CommandLine(ptPath);
        addClientArgs(cmd, listenAddress, getModeAddress, proxyAddress);
        exec();

        if (!LanternUtils.waitForServer(listenAddress, 60000)) {
            throw new RuntimeException(String.format("Unable to start %1$s",
                    getLogName()));
        }

        return listenAddress;
    }

    @Override
    public void stopClient() {
        LOGGER.info("Stopping {} client", getLogName());
        cmdExec.getWatchdog().destroyProcess();
    }

    @Override
    public void startServer(int listenPort, InetSocketAddress giveModeAddress) {
        LOGGER.info("Starting {} client", getLogName());

        try {
            String listenIp = NetworkUtils.getLocalHost().getHostAddress();
            cmd = new CommandLine(ptPath);
            addServerArgs(cmd, listenIp, listenPort, giveModeAddress);
            exec();
            if (!LanternUtils.waitForServer(listenIp, listenPort, 60000)) {
                throw new RuntimeException(String.format(
                        "Unable to start %1$s server", getLogName()));
            }
        } catch (UnknownHostException uhe) {
            throw new RuntimeException("Unable to determine interface ip: "
                    + uhe.getMessage(), uhe);
        }
    }

    @Override
    public void stopServer() {
        LOGGER.info("Stopping {} server", getLogName());
        cmdExec.getWatchdog().destroyProcess();
    }

    private File findBasePath() {
        final File rel = new File(ptRelativePath);
        if (rel.isDirectory())
            return rel;

        if (SystemUtils.IS_OS_MAC_OSX) {
            return new File("./install/osx", ptRelativePath);
        }

        if (SystemUtils.IS_OS_WINDOWS) {
            return new File("./install/win", ptRelativePath);
        }

        if (SystemUtils.OS_ARCH.contains("64")) {
            return new File("./install/linux_x86_64", ptRelativePath);
        }
        return new File("./install/linux_x86_32", ptRelativePath);
    }

    private void copyToConfigFolder() {
        File from = new File(ptBasePath);
        File to = new File(LanternClientConstants.CONFIG_DIR
                + File.separator
                + ptRelativePath);

        synchronized (ALREADY_COPIED_TRANSPORTS) {
            if (!ALREADY_COPIED_TRANSPORTS.contains(getClass())) {
                LOGGER.info("Copying {} from {} to {}",
                        getLogName(),
                        from.getAbsolutePath(),
                        to.getAbsolutePath());
                try {
                    FileUtils.copyDirectory(from, to);
                } catch (Exception e) {
                    throw new Error(String.format(
                            "Unable to stage %1$s to .lantern: %2$s",
                            getLogName(), e.getMessage()), e);
                }
                ALREADY_COPIED_TRANSPORTS.add(getClass());
            } else {
                LOGGER.info("Not copying {} because it's already been copied",
                        getLogName());
            }
        }

        // Always update base path to point to copied location
        ptBasePath = to.getAbsolutePath();
    }

    private void initPtPath() {
        File executable = null;
        for (String name : executableNames) {
            executable = new File(ptBasePath + "/" + name);
            ptPath = executable.getAbsolutePath();
            if (executable.exists()) {
                break;
            } else {
                LOGGER.info("executable not found at {}",
                        ptPath);
                executable = null;
                ptPath = null;
            }
        }
        if (executable == null) {
            String message = String.format(
                    "%1$s executable not found in search path", getLogName());
            LOGGER.error(message, ptPath);
            throw new Error(message);
        }
    }

    private void exec() {
        cmdExec = new DefaultExecutor();
        cmdExec.setStreamHandler(new LoggingStreamHandler(LOGGER, System.in));
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

    private String getLogName() {
        return getClass().getSimpleName();
    }

    protected static String stringify(Object value) {
        return String.format("%1$s", value);
    }
}
