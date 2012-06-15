package org.lantern;

import java.io.File;
import java.util.concurrent.Executors;

import org.apache.commons.lang.SystemUtils;
import org.jboss.netty.channel.socket.ClientSocketChannelFactory;
import org.jboss.netty.channel.socket.nio.NioClientSocketChannelFactory;
import org.lantern.exceptional4j.ExceptionalUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
    
    /**
     * Default size of download chunks -- the range we'll request even if the
     * other side is serving much smaller content, just in case we're able
     * to chunk. The minus one is just there due to an off by one error on the
     * client/LAE proxy.
     */
    public static final long CHUNK_SIZE = 2000000 - 1;
    
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
    
    /**
     * Configuration file for starting at login on Gnome.
     */
    public static final File GNOME_AUTOSTART =
        new File(System.getProperty("user.home"), ".config/autostart/lantern.desktop");

    public static final String CONNECT_ON_LAUNCH = "connectOnLaunch";

    public static final String START_AT_LOGIN = "startAtLogin";

    public static final File CONFIG_DIR = 
        new File(System.getProperty("user.home"), ".lantern");
    
    public static final File DEFAULT_SETTINGS_FILE = 
        new File(CONFIG_DIR, "settings.json");
    
    public static File DATA_DIR;
    
    public static File LOG_DIR;
    
    public static ClientSocketChannelFactory clientSocketChannelFactory;

    static {
        try {
            Class.forName("org.lantern.LanternControllerUtils");
            DATA_DIR = null;
            LOG_DIR = null;
            clientSocketChannelFactory = null;
        } catch (final ClassNotFoundException e) {
            // Only load these if we're not on app engine.
            if (SystemUtils.IS_OS_WINDOWS) {
                //logDirParent = CommonUtils.getDataDir();
                DATA_DIR = new File(System.getenv("APPDATA"), "Lantern");
                LOG_DIR = new File(DATA_DIR, "logs");
            } else if (SystemUtils.IS_OS_MAC_OSX) {
                final File homeLibrary = 
                    new File(System.getProperty("user.home"), "Library");
                DATA_DIR = CONFIG_DIR;//new File(homeLibrary, "Logs");
                final File allLogsDir = new File(homeLibrary, "Logs");
                LOG_DIR = new File(allLogsDir, "Lantern");
            } else {
                DATA_DIR = new File(System.getProperty("user.home"), ".lantern");
                LOG_DIR = new File(DATA_DIR, "logs");
            }

            if (!DATA_DIR.isDirectory()) {
                if (!DATA_DIR.mkdirs()) {
                    System.err.println("Could not create parent at: "
                            + DATA_DIR);
                }
            }
            if (!LOG_DIR.isDirectory()) {
                if (!LOG_DIR.mkdirs()) {
                    System.err.println("Could not create dir at: " + LOG_DIR);
                }
            }
            if (!CONFIG_DIR.isDirectory()) {
                if (!CONFIG_DIR.mkdirs()) {
                    System.err.println("Could not make config directory at: "+
                        CONFIG_DIR);
                }
            }
            
            // This is initialized here because we don't want to load it on
            // App Engine -- DO NOT MOVE.
            clientSocketChannelFactory = new NioClientSocketChannelFactory(
                    Executors.newCachedThreadPool(),
                    Executors.newCachedThreadPool());
        }
    }

}
