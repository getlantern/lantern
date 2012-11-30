package org.lantern;

public class RuntimeSettings {

    
    private static int apiPort;
    
    public static int getApiPort() {
        return apiPort;
    }

    public static void setApiPort(final int apiPort) {
        RuntimeSettings.apiPort = apiPort;
    }

    public static String getLocalEndpoint() {
        return "http://localhost:"+RuntimeSettings.getApiPort();
    }
}
