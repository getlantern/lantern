package org.lantern;

/**
 * Interface for settings that are mutable. This allows helper classes to
 * implement the same interface as data beans.
 */
public interface MutableSettings {

    void setCountry(Country country);
    
    void setGetMode(boolean getMode);
    
    void setStartAtLogin(boolean start);
    
    void setSystemProxy(boolean isSystemProxy);
    
    void setPort(int port);

    void setEmail(String email);
    
    void setPassword(String password);
    
    void setSavePassword(boolean savePassword);

}
