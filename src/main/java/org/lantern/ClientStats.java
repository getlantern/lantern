package org.lantern;

import java.net.InetAddress;
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
    void addDownBytesFromPeers(long bytes, InetAddress peerAddress);

    /**
     * bytes sent upstream on behalf of another lantern by this lantern
     */
    void addUpBytesToPeers(long bytes, InetAddress peerAddress);

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

    /**
     * Record that we've proxied traffic for the given {@link InetAddress}.
     * 
     * @param address
     */
    void addProxiedClientAddress(InetAddress address);
    
    /**
     * Return the bytes proxied for Iran since the last time
     * getBytesProxiedForIran() was called.
     * 
     * @return
     */
    long getBytesProxiedForIran();
    
    long getGlobalBytesProxiedForIran();
    
    /**
     * Return the bytes proxied for China since the last time
     * getBytesProxiedForChina() was called.
     * 
     * @return
     */
    long getBytesProxiedForChina();
    
    long getGlobalBytesProxiedForChina();

    /**
     * Gives a count of the # of distinct {@link InetAddress}es for which we've
     * proxied data.
     * 
     * @return
     */
    long getCountOfDistinctProxiedClientAddresses();

    void resetCumulativeStats();

}
