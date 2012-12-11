package org.lantern.state;

/**
 * Interface for settings that are mutable. This allows helper classes to
 * implement the same interface as data beans.
 */
public interface ModelService {

    //void setCountry(Country country);
    
    void setGetMode(boolean getMode);
    
    //void setMode(boolean getMode);
    
    void setStartAtLogin(boolean start);
    
    void setSystemProxy(boolean isSystemProxy);
    
    //void setPort(int port);

    //void setEmail(String email);
    
    //void setPassword(String password);
    
    //void setSavePassword(boolean savePassword);

    void setProxyAllSites(boolean proxyAll);

}
