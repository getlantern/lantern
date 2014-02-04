package org.lantern.proxy.pt;

import java.net.InetSocketAddress;

/**
 * <p>
 * Binding to a <a
 * href="https://www.torproject.org/docs/pluggable-transports.html">pluggable
 * transport</a> like <a href="https://fteproxy.org/>fteproxy</a>.
 * </p>
 * 
 * <p>
 * All implementations must include a single-argument constructor taking a
 * {@link Map<String, Object>} of configuration properties.
 * </p>
 */
public interface PluggableTransport {
    /**
     * Start the client-side of a pluggable transport.
     * 
     * @param getModeAddress
     *            the address on which the GetMode proxy is listening.
     * @param proxyAddress
     *            the address on which the remote proxy is listening
     * @return the {@link InetSocketAddress} on which the client is listening.
     */
    InetSocketAddress startClient(InetSocketAddress getModeAddress,
            InetSocketAddress proxyAddress);
    
    void stopClient();

    /**
     * Start the server-side of a pluggable transport
     * 
     * @param giveModeAddress
     *            the address on which the GiveMode proxy is listening.
     * @return the {@link InetSocketAddress} on which the server is listening.
     */
    InetSocketAddress startServer(InetSocketAddress giveModeAddress);
    
    void stopServer();
}
