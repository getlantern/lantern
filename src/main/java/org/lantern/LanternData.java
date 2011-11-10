package org.lantern;

import javax.management.MXBean;

@MXBean(true)
public interface LanternData {

    long getTotalBytesProxied();
    
    long getDirectBytes();
    
    int getTotalProxiedRequests();
    
    int getDirectRequests();
}
