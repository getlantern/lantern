package org.lantern;

import java.net.InetAddress;

public class ConnectivityChangedEvent {

    private final boolean isConnected;
    private final InetAddress newIp;
    private final boolean ipChanged;

    public ConnectivityChangedEvent(boolean nowConnected, boolean ipChanged, InetAddress newIp) {
        this.isConnected = nowConnected;
        this.ipChanged = ipChanged;
        this.newIp = newIp;
    }

    public boolean isConnected() {
        return isConnected;
    }

    public InetAddress getNewIp() {
        return newIp;
    }

    public boolean isIpChanged() {
        return ipChanged;
    }

    @Override
    public String toString() {
        String nowConnectedStr = isConnected ? "now connected" : "disconnected";
        String ipChangedStr = ipChanged ? "ip changed" : "ip unchanged";
        return "ConnectivityChanged(" + nowConnectedStr + ", " + ipChangedStr + ", " + newIp + ")";
    }
}
