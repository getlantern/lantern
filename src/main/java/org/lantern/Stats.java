package org.lantern;

public interface Stats {

    long getUptime();

    long getPeerCount();

    long getPeerCountThisRun();

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

    String getCountryCode();

    String getVersion();

}