package org.lantern.client;

import javax.management.MXBean;

/**
 * Bean for connection pool data.
 */
@MXBean(true)
public interface HttpRequestHandlerData {

    int getTotalBrowserToProxyConnections();
    
    int getTotalBrowserToProxyConnectionsAllClasses();
    
    int getCurrentBrowserToProxyConnections();
    
    String getIncomingIps();
    
    int getMessagesReceived();
    
    long getLifetime();
}
