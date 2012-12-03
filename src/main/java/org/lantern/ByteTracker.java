package org.lantern;


public interface ByteTracker {

    void addUpBytes(long bytes);
    void addDownBytes(long bytes);
}
