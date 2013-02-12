package org.lantern.state;

import java.util.List;

import org.lantern.state.Settings.Mode;

/**
 * Interface for settings that are mutable. This allows helper classes to
 * implement the same interface as data beans.
 */
public interface ModelService {

    //void setCountry(Country country);
    
    //void setGetMode(boolean getMode);
    
    //void setMode(boolean getMode);
    
    void setRunAtSystemStart(boolean start);
    
    void setSystemProxy(boolean isSystemProxy);
    
    void setAutoReport(boolean report);
    
    //void setAutoConnect(boolean autoConnect);
    
    //void setPort(int port);

    //void setEmail(String email);
    
    //void setPassword(String password);
    
    //void setSavePassword(boolean savePassword);

    void setProxyAllSites(boolean proxyAll);

    void setMode(Mode mode);

    void invite(List<String> emails);

    void setProxiedSites(List<String> proxiedSites);

    void resetProxiedSites();

}
