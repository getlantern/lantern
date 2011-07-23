package org.lantern;

/**
 * Constants for Lantern.
 */
public class LanternConstants {

    /**
     * This is the version of Lantern we're running. This is automatically
     * replaced when we push new releases.
     */
    public static final String VERSION = "lantern_version_tok";
    
    public static final String VERSION_KEY = "v";
    
    /**
     * This is the local proxy port data is relayed to on the "server" side
     * of P2P connections.
     */
    public static final int PLAINTEXT_LOCALHOST_PROXY_PORT = 7777;
    public static final int LANTERN_LOCALHOST_HTTP_PORT = 8787;
    
    public static final int LANTERN_LOCALHOST_HTTPS_PORT = 8788;
    
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
    
    //public static final String UPDATE_MESSAGE_KEY = "upm";
    
    /**
     * The key for the update JSON object.
     */
    public static final String UPDATE_KEY = "uk";
    
    //public static final String UPDATE_TITLE_KEY = "upt";
}
