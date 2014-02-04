package org.lantern.proxy.pt;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.util.Map;

import org.apache.commons.exec.CommandLine;
import org.apache.commons.exec.DefaultExecuteResultHandler;
import org.apache.commons.exec.DefaultExecutor;
import org.apache.commons.exec.ExecuteWatchdog;
import org.apache.commons.exec.Executor;
import org.apache.commons.exec.PumpStreamHandler;
import org.apache.commons.exec.ShutdownHookProcessDestroyer;
import org.lantern.LanternUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class FTE implements PluggableTransport {
    private static final Logger LOGGER = LoggerFactory.getLogger(FTE.class);
    private static final String FTEPROXY_LOCATION = "/Users/ox.to.a.cart/git/fteproxy_master/bin/fteproxy";
    private Executor client;
    private Executor server;

    public FTE(Map<String, Object> properties) {
        super();
    }

    @Override
    public InetSocketAddress startClient(
            InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress) {
        LOGGER.debug("Starting FTE client");
        InetSocketAddress address = new InetSocketAddress(
                getModeAddress.getAddress(),
                findFreePort());

        client = fteProxy(
                "--mode", "client",
                "--client_port", address.getPort(),
                "--server_ip", proxyAddress.getAddress().getHostAddress(),
                "--server_port", proxyAddress.getPort());

        if (!LanternUtils.waitForServer(address, 5000)) {
            throw new RuntimeException("Unable to start FTE client");
        }

        return address;
    }

    @Override
    public void stopClient() {
        client.getWatchdog().destroyProcess();
    }

    @Override
    public InetSocketAddress startServer(InetSocketAddress giveModeAddress) {
        LOGGER.debug("Starting FTE server");
        InetSocketAddress address = new InetSocketAddress(
                giveModeAddress.getAddress(),
                findFreePort());

        server = fteProxy(
                "--mode", "server",
                "--server_port", address.getPort(),
                "--proxy_ip", giveModeAddress.getAddress().getHostAddress(),
                "--proxy_port", giveModeAddress.getPort());

        if (!LanternUtils.waitForServer(address, 5000)) {
            throw new RuntimeException("Unable to start FTE server");
        }

        return address;
    }

    @Override
    public void stopServer() {
        server.getWatchdog().destroyProcess();
    }

    private Executor fteProxy(Object... args) {
        Executor cmdExec = new DefaultExecutor();
        cmdExec.setStreamHandler(new PumpStreamHandler(System.out, System.err,
                System.in));
        cmdExec.setProcessDestroyer(new ShutdownHookProcessDestroyer());
        cmdExec.setWatchdog(new ExecuteWatchdog(
                ExecuteWatchdog.INFINITE_TIMEOUT));
        CommandLine cmd = new CommandLine(FTEPROXY_LOCATION);
        for (Object arg : args) {
            cmd.addArgument(String.format("\"%1$s\"", arg));
        }
        DefaultExecuteResultHandler resultHandler = new DefaultExecuteResultHandler();
        try {
            cmdExec.execute(cmd, resultHandler);
            return cmdExec;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    /**
     * Cargo culted from org.eclipse.jdt.launching.SocketUtil.
     * 
     * @return
     */
    private int findFreePort() {
        ServerSocket socket = null;
        try {
            socket = new ServerSocket(0);
            return socket.getLocalPort();
        } catch (IOException e) {
        } finally {
            if (socket != null) {
                try {
                    socket.close();
                } catch (IOException e) {
                }
            }
        }
        return -1;
    }
}
