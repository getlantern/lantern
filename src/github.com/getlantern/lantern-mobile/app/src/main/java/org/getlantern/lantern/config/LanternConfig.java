package org.getlantern.lantern.config;

/**
 * Created by todd on 8/7/15.
 */
public interface LanternConfig {

    public final static String APP_NAME = "Lantern";

    public final static int HTTP_PORT = 9121;
    public final static int SOCKS_PORT = 9131;
    public final static String UDPGW_SERVER = "104.236.158.87:7300";
    public final static String ENABLE_VPN = "org.getlantern.lantern.intent.action.ENABLE";
    public final static String DISABLE_VPN = "org.getlantern.lantern.intent.action.DISABLE";
    public final static String START_BUTTON_TEXT = "START";
    public final static String STOP_BUTTON_TEXT = "STOP";
}  
