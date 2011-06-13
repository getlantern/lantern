package org.lantern;

public class StatsTracker implements LanternData {
    
    private volatile long bytesProxied;
    
    private volatile long directBytes;

    private volatile int proxiedRequests;

    private volatile int directRequests;

    public void addBytesProxied(final long bp) {
        bytesProxied += bp;
    }
    
    public long getBytesProxied() {
        return bytesProxied;
    }

    public void addDirectBytes(final int db) {
        directBytes += db;
    }

    public long getDirectBytes() {
        return directBytes;
    }

    public void incrementDirectRequests() {
        this.directRequests++;
    }

    public void incrementProxiedRequests() {
        this.proxiedRequests++;
    }

    public int getProxiedRequests() {
        return proxiedRequests;
    }

    public int getDirectRequests() {
        return directRequests;
    }

}
