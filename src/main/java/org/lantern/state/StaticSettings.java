package org.lantern.state;

import org.lantern.LanternUtils;

public class StaticSettings {

    private static int apiPort = LanternUtils.randomPort();

    private static Model model;

    public static void setModel(Model model) {
        StaticSettings.model = model;
    }

    public static int getApiPort() {
        return apiPort;
    }

    public static void setApiPort(int apiPort) {
        StaticSettings.apiPort = apiPort;
    }

    public static String getLocalEndpoint() {
        return getLocalEndpoint(StaticSettings.getApiPort(), model.getServerPrefix());
    }

    public static String getLocalEndpoint(final int port, String prefix) {
        return "http://127.0.0.1:"+port + prefix;
    }

    public static String getPrefix() {
        return model.getServerPrefix();
    }
}
