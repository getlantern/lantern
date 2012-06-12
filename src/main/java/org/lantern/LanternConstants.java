package org.lantern;

import java.io.File;

import org.lantern.exceptional4j.ExceptionalUtils;

/**
 * Constants for Lantern.
 */
public class LanternConstants {
    
    static final long START_TIME = System.currentTimeMillis();
    
    /**
     * This is the version of Lantern we're running. This is automatically
     * replaced when we push new releases.
     */
    public static final String VERSION = "lantern_version_tok";
    
    public static final String GET_EXCEPTIONAL_API_KEY = 
        ExceptionalUtils.NO_OP_KEY;
    
    //public static final String LANTERN_JID = "lantern-controller@appspot.com";
    public static final String LANTERN_JID = "lanternctrl@appspot.com";
    
   
    public static final String VERSION_KEY = "v";
    
    /**
     * This is the local proxy port data is relayed to on the "server" side
     * of P2P connections.
     */
    public static final int PLAINTEXT_LOCALHOST_PROXY_PORT = 
        LanternUtils.randomPort();
    
    public static final int LANTERN_LOCALHOST_HTTP_PORT = 8787;
    
    public static final String USER_NAME = "un";
    public static final String PASSWORD = "pwd";
    
    public static final String DIRECT_BYTES = "db";
    public static final String BYTES_PROXIED = "bp";
    
    public static final String REQUESTS_PROXIED = "rp";
    public static final String DIRECT_REQUESTS = "dr";
    
    public static final String MACHINE_ID = "m";
    public static final String COUNTRY_CODE = "cc";
    public static final String WHITELIST_ADDITIONS = "wa";
    public static final String WHITELIST_REMOVALS = "wr";
    public static final String SERVERS = "s";
    public static final String UPDATE_TIME = "ut";
    
    
    /*
     * The following are keys in the properties files.
     */
    public static final String FORCE_CENSORED = "forceCensored";
    
    /**
     * The key for the update JSON object.
     */
    public static final String UPDATE_KEY = "uk";
    
    public static final String UPDATE_VERSION_KEY = "number";

    public static final String UPDATE_URL_KEY = "url";
    
    public static final String UPDATE_MESSAGE_KEY = "message";
    
    public static final String UPDATE_RELEASED_KEY = "released";

    
    /**
     * The length of keys in translation property files.
     */
    public static final int I18N_KEY_LENGTH = 40;
    
    /**
     * Plist file for launchd on OSX.
     */
    public static final File LAUNCHD_PLIST =
        new File(System.getProperty("user.home"), "Library/LaunchAgents/org.lantern.plist");

    public static final String CONNECT_ON_LAUNCH = "connectOnLaunch";

    public static final String START_AT_LOGIN = "startAtLogin";

    public static final File DEFAULT_SETTINGS_FILE = 
        new File(LanternUtils.configDir(), "settings.json");

    

}
