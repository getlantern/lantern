package org.lantern;

import org.jboss.netty.channel.Channel;
import org.lantern.annotation.Keep;

@Keep
public interface Stats {

    long getUptime();

    long getUpBytesThisRun();

    long getDownBytesThisRun();

    long getUpBytesThisRunForPeers();

    long getUpBytesThisRunViaProxies();

    long getUpBytesThisRunToPeers();

    long getDownBytesThisRunForPeers();

    long getDownBytesThisRunViaProxies();

    long getDownBytesThisRunFromPeers();

    long getUpBytesPerSecond();

    long getDownBytesPerSecond();

    long getUpBytesPerSecondForPeers();

    long getUpBytesPerSecondViaProxies();

    long getDownBytesPerSecondForPeers();

    long getDownBytesPerSecondViaProxies();

    long getDownBytesPerSecondFromPeers();

    long getUpBytesPerSecondToPeers();

    long getTotalBytesProxied();

    long getDirectBytes();

    int getTotalProxiedRequests();

    int getDirectRequests();

    boolean isUpnp();

    boolean isNatpmp();

    String getVersion();

    void setNatpmp(boolean natpmp);

    void setUpnp(boolean upnp);

    void resetCumulativeStats();

    void addDownBytesViaProxies(long bytes);

    void addUpBytesViaProxies(long bytes);

    void incrementProxiedRequests();

    void addUpBytesToPeers(long bytes);

    void addDownBytesFromPeers(long bytes);

    void addUpBytesForPeers(long bytes);

    void addDownBytesForPeers(long bytes);

    void addDirectBytes(long bytes);

    void addBytesProxied(long bytes, Channel channel);

}