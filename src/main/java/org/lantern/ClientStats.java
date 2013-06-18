package org.lantern;

import org.jboss.netty.channel.Channel;

public interface ClientStats extends Stats {

    void setNatpmp(boolean natpmp);

    void setUpnp(boolean upnp);

    void incrementProxiedRequests();

    void addUpBytesViaProxies(long bytes);

    void addUpBytesForPeers(long bytes);

    void addDownBytesViaProxies(long bytes);

    void addDownBytesFromPeers(long bytes);

    void addDownBytesForPeers(long bytes);

    void addDirectBytes(long bytes);

    void addUpBytesToPeers(long bytes);

    void addBytesProxied(long bytes, Channel channel);

    void resetCumulativeStats();

}
