package org.lantern.state;

import java.util.List;

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

    void setShowFriendPrompts(boolean showFriendPrompts);

    //void setAutoConnect(boolean autoConnect);

    //void setPort(int port);

    //void setEmail(String email);

    //void setPassword(String password);

    //void setSavePassword(boolean savePassword);

    void setProxyAllSites(boolean proxyAll);

    void setMode(Mode mode);

    Mode getMode();

    void resetProxiedSites();

    void setProxiedSites(List<String> proxiedSites);

}
