package org.lantern;

import java.net.InetSocketAddress;

import org.lantern.proxy.GetModeProxy;

public interface ClientStats extends Stats {

    void setNatpmp(boolean natpmp);

    void setUpnp(boolean upnp);

    void incrementProxiedRequests();

    /**
     * request bytes this lantern proxy sent to other lanterns for proxying
     */
    void addUpBytesViaProxies(long bytes);

    /**
     * response bytes downloaded by Peers for this lantern
     */
    void addDownBytesViaProxies(long bytes);

    /**
     * bytes uploaded on behalf of another lantern by this lantern
     */
    void addUpBytesForPeers(long bytes);

    /**
     * reply bytes sent to peers by this lantern
     */
    void addDownBytesForPeers(long bytes);

    /**
     * request bytes sent by peers to this lantern
     */
    void addDownBytesFromPeers(long bytes);

    /**
     * bytes sent upstream on behalf of another lantern by this lantern
     */
    void addUpBytesToPeers(long bytes);

    /**
     * bytes that were sent/received from the {@link GetModeProxy} but not
     * proxied via remote Lantern proxies (i.e. direct connection to server
     * endpoint).
     * 
     * @param bytes
     */
    void addDirectBytes(long bytes);

    /**
     * bytes proxied by the {@link GetModeProxy} via external Lantern proxies,
     * on behalf of a local client (e.g. browser).
     * 
     * @param bytes
     *            the number of bytes sent/received to the local client
     * @param localProxyAddress
     *            the local address of the {@link GetModeProxy}, used for
     *            geolocation
     */
    void addBytesProxied(long bytes, InetSocketAddress localProxyAddress);

    void resetCumulativeStats();

}
