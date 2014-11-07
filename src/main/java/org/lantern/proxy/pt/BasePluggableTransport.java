package org.lantern.proxy.pt;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.ExecuteWatchdog;
import org.apache.commons.exec.Executor;
import org.apache.commons.exec.ShutdownHookProcessDestroyer;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.SystemUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.util.Threads;
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

    protected File exe;
    private CommandLine cmd;
    private Executor cmdExec;

    protected String ptBasePath;

    /**
     * Construct a new Flashlight pluggable transport.
     * 
     * @param copyToConfigFolder
     *            - if true, the pluggable transport will be copied to and run
     *            from the .lantern folder (necessary if the pluggable transport
     *            modifies files in its path)
     * @param relativePath
     *            - relative path of pluggable transport from the root of the 
     *            jar
     * @param executableName
     *            - the name of the executable (not including .exe)
     */
    protected BasePluggableTransport(boolean copyToConfigFolder,
            String relativePath,
            String executableName) {
        String path = relativePath + "/" + executableName;
        if (SystemUtils.IS_OS_WINDOWS) {
            path += ".exe";
        }
        try {
            this.exe = LanternUtils.extractExecutableFromJar(path, 
                    LanternClientConstants.DATA_DIR);
        } catch (final IOException e) {
            throw new Error("Could not extract jar file from:"+ path, e);
        }
        if (!exe.exists()) {
            String message = String.format(
                "%1$s executable missing at %2$s", getLogName(), exe);
            LOGGER.error(message, exe);
            throw new Error(message);
        }
        
        if (!exe.canExecute()) {
            String message = String.format(
                "%1$s executable not executable at %2$s", getLogName(), exe);
            LOGGER.error(message, exe);
            throw new Error(message);
        }
        this.ptBasePath = exe.getParentFile().getAbsolutePath();
        if (copyToConfigFolder) {
            copyToConfigFolder(exe, relativePath);
        }
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

        cmd = new CommandLine(this.exe);
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
    public void startServer(final int listenPort,
            InetSocketAddress giveModeAddress) {
        LOGGER.info("Starting {} server", getLogName());

        try {
            final String listenIp = NetworkUtils.getLocalHost()
                    .getHostAddress();
            cmd = new CommandLine(this.exe);
            addServerArgs(cmd, listenIp, listenPort, giveModeAddress);
            final Future<Integer> exitFuture = exec();

            // Record exception related to startup of server
            final AtomicReference<RuntimeException> exception = new AtomicReference<RuntimeException>();

            // Check for termination of process
            new Thread() {
                public void run() {
                    try {
                        exitFuture.get();
                    } catch (Exception e) {
                        exception.set(new RuntimeException(
                                String.format(
                                        "Unable to execute process: %1$s",
                                        e.getMessage()), e));
                    }
                    synchronized (exception) {
                        exception.notifyAll();
                    }
                }
            }.start();

            // Check for server listening
            new Thread() {
                public void run() {
                    if (!LanternUtils
                            .waitForServer(listenIp, listenPort, 60000)) {
                        exception.set(new RuntimeException(String.format(
                                "Unable to start %1$s server", getLogName())));
                    }
                    synchronized (exception) {
                        exception.notifyAll();
                    }
                }
            }.start();

            // Take the first exception
            try {
                synchronized (exception) {
                    exception.wait();
                }
            } catch (InterruptedException ie) {
                throw new RuntimeException(
                        "Unable to determine status of server");
            }
            RuntimeException e = exception.get();
            if (e != null) {
                throw e;
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

    private void copyToConfigFolder(final File exe, final String relativePath) {
        final File from = exe.getParentFile();
        final File to = new File(LanternClientConstants.CONFIG_DIR, relativePath);

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

    private Future<Integer> exec() {
        cmdExec = new DefaultExecutor();
        cmdExec.setStreamHandler(buildLoggingStreamHandler(LOGGER, System.in));
        cmdExec.setProcessDestroyer(new ShutdownHookProcessDestroyer());
        cmdExec.setWatchdog(new ExecuteWatchdog(
                ExecuteWatchdog.INFINITE_TIMEOUT));
        LOGGER.info("About to run cmd: {}", cmd);
        try {
            return Threads.newSingleThreadExecutor("PluggableTransportRunner")
                    .submit(
                            new Callable<Integer>() {
                                @Override
                                public Integer call() throws Exception {
                                    return cmdExec.execute(cmd);
                                }
                            });
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
    
    protected LoggingStreamHandler buildLoggingStreamHandler(
            Logger logger,
            InputStream is) {
        return new LoggingStreamHandler(logger, is);
    }

    private String getLogName() {
        return getClass().getSimpleName();
    }

    protected static String stringify(Object value) {
        return String.format("%1$s", value);
    }
}
