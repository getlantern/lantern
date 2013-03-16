package org.lantern.util;

public interface LanternTrafficCounter {

    boolean isConnected();

    int getNumSockets();

    long getLastConnected();

    long getCumulativeReadBytes();

    long getCumulativeWrittenBytes();

    long getCurrentReadBytes();

    long getCurrentWrittenBytes();

}
