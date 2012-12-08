package org.lantern.state;

import org.lantern.LanternUtils;


public class StaticSettings {

    private static int apiPort = LanternUtils.randomPort();

    public static int getApiPort() {
        return apiPort;
    }

    public static void setApiPort(int apiPort) {
        StaticSettings.apiPort = apiPort;
    }
    
    public static String getLocalEndpoint() {
        return getLocalEndpoint(getApiPort());
    }
    
    
    public static String getLocalEndpoint(final int port) {
        return "http://127.0.0.1:"+port;
    }
}
