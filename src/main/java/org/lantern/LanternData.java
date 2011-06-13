package org.lantern;

import javax.management.MXBean;

@MXBean(true)
public interface LanternData {

    long getBytesProxied();
    
    long getDirectBytes();
    
    int getProxiedRequests();
    
    int getDirectRequests();
}
