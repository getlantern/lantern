package org.lantern;

import org.jboss.netty.channel.Channel;

public class StatsTrackerStub implements Stats {

    @Override
    public long getUptime() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getUpBytesThisRun() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDownBytesThisRun() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getUpBytesThisRunForPeers() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getUpBytesThisRunViaProxies() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getUpBytesThisRunToPeers() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDownBytesThisRunForPeers() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDownBytesThisRunViaProxies() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDownBytesThisRunFromPeers() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getUpBytesPerSecond() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDownBytesPerSecond() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getUpBytesPerSecondForPeers() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getUpBytesPerSecondViaProxies() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDownBytesPerSecondForPeers() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDownBytesPerSecondViaProxies() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDownBytesPerSecondFromPeers() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getUpBytesPerSecondToPeers() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getTotalBytesProxied() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public long getDirectBytes() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public int getTotalProxiedRequests() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public int getDirectRequests() {
        // TODO Auto-generated method stub
        return 0;
    }

    @Override
    public boolean isUpnp() {
        // TODO Auto-generated method stub
        return false;
    }

    @Override
    public boolean isNatpmp() {
        // TODO Auto-generated method stub
        return false;
    }

    @Override
    public String getVersion() {
        // TODO Auto-generated method stub
        return null;
    }

    @Override
    public void setNatpmp(boolean natpmp) {
        // TODO Auto-generated method stub

    }

    @Override
    public void setUpnp(boolean upnp) {
        // TODO Auto-generated method stub

    }

    @Override
    public void resetCumulativeStats() {
        // TODO Auto-generated method stub

    }

    @Override
    public void addDownBytesViaProxies(long bytes) {
        // TODO Auto-generated method stub

    }

    @Override
    public void addUpBytesViaProxies(long bytes) {
        // TODO Auto-generated method stub

    }

    @Override
    public void incrementProxiedRequests() {
        // TODO Auto-generated method stub

    }

    @Override
    public void addUpBytesToPeers(long bytes) {
        // TODO Auto-generated method stub

    }

    @Override
    public void addDownBytesFromPeers(long bytes) {
        // TODO Auto-generated method stub

    }

    @Override
    public void addUpBytesForPeers(long bytes) {
        // TODO Auto-generated method stub

    }

    @Override
    public void addDownBytesForPeers(long bytes) {
        // TODO Auto-generated method stub

    }

    @Override
    public void addDirectBytes(long bytes) {
        // TODO Auto-generated method stub

    }

    @Override
    public void addBytesProxied(long bytes, Channel channel) {
        // TODO Auto-generated method stub

    }

}
