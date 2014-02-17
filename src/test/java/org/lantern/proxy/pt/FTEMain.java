package org.lantern.proxy.pt;

import java.net.InetSocketAddress;
import java.util.Properties;

/**
 * <p>
 * This simple program runs two local LittleProxies that talk to each other via
 * two local fteproxy instances (client and server). After running this program,
 * you can do this:
 * </p>
 * 
 * <pre>
 * curl -x 127.0.0.1:8080 http://www.google.com
 * </pre>
 */
public class FTEMain extends ChainedMain {
    private static final int FTEPROXY_CLIENT_PORT = 8081;
    private static final int FTEPROXY_SERVER_PORT = 8082;

    private InetSocketAddress clientAddress;

    public static void main(String[] args) throws Exception {
        new FTEMain().run();
    }

    public void run() throws Exception {
        // Start LittleProxy servers
        super.run();

        InetSocketAddress getModeAddress = new InetSocketAddress("localhost",
                FTEPROXY_CLIENT_PORT);
        InetSocketAddress serverAddress = new InetSocketAddress("localhost",
                FTEPROXY_SERVER_PORT);
        InetSocketAddress upstreamProxyAddress = new InetSocketAddress(
                "localhost", LITTLEPROXY_UPSTREAM_PORT);

        // Common Properties
        Properties props = new Properties();

        // Client
        FTE client = new FTE(props);
        this.clientAddress = client.startClient(getModeAddress, serverAddress);

        // Server
        FTE server = new FTE(props);
        server.startServer(FTEPROXY_SERVER_PORT, upstreamProxyAddress);
    }

    @Override
    protected int getUpstreamPort() {
        return this.clientAddress.getPort();
    }

    @Override
    protected boolean requiresEncryption() {
        return false;
    }
}
