package org.lantern;

public class StatsTracker implements LanternData {
    
    private volatile long bytesProxied;
    
    private volatile long directBytes;

    private volatile int proxiedRequests;

    private volatile int directRequests;
    
    
    public StatsTracker() {}

    public void clear() {
        bytesProxied = 0L;
        directBytes = 0L;
        proxiedRequests = 0;
        directRequests = 0;
    }

    public void addBytesProxied(final long bp) {
        bytesProxied += bp;
    }
    
    @Override
    public long getBytesProxied() {
        return bytesProxied;
    }

    public void addDirectBytes(final int db) {
        directBytes += db;
    }

    @Override
    public long getDirectBytes() {
        return directBytes;
    }

    public void incrementDirectRequests() {
        this.directRequests++;
    }

    public void incrementProxiedRequests() {
        this.proxiedRequests++;
    }

    @Override
    public int getProxiedRequests() {
        return proxiedRequests;
    }

    @Override
    public int getDirectRequests() {
        return directRequests;
    }

}
