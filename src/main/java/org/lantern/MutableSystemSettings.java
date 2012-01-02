package org.lantern;

/**
 * Interface for system properties that are mutable.
 */
public interface MutableSystemSettings {

    void setStartAtLogin(boolean start);
    
    void setSystemProxy(boolean isSystemProxy);
    
    void setPort(int port);
    
    void setLocation(String location);
    
    void setConnectOnLaunch(boolean connectOnLaunch);
}
