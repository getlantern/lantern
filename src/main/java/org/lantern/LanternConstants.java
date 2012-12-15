package org.lantern;

import java.io.File;
import java.nio.charset.Charset;

import org.apache.commons.lang.SystemUtils;
import org.lantern.exceptional4j.ExceptionalUtils;

/**
 * Constants for Lantern.
 */
public class LanternConstants {
    
    public static final String FALLBACK_SERVER_HOST = "fallback_server_host_tok";
    public static final String FALLBACK_SERVER_PORT = "fallback_server_port_tok";
    
    public static final String FALLBACK_SERVER_USER = "fallback_server_user_tok";
    public static final String FALLBACK_SERVER_PASS = "fallback_server_pass_tok";
    
    public static final File GEOIP = 
            new File(LanternConstants.DATA_DIR, "GeoIP.dat");
    
    public static final long START_TIME = System.currentTimeMillis();

    public static final int DASHCACHE_MAXAGE = 60 * 5;
    
    /**
     * This is the version of Lantern we're running. This is automatically
     * replaced when we push new releases.
     */
    public static final String VERSION = "lantern_version_tok";
    
    public static final String API_VERSION = "0.0.1";
    
    public static final String BUILD_TIME = "build_time_tok";
    
    public static final String UNCENSORED_ID = "-lan-";
    
    /**
     * We make range requests of the form "bytes=x-y" where
     * y <= x + CHUNK_SIZE
     * in order to chunk and parallelize downloads of large entities. This
     * is especially important for requests to laeproxy since it is subject
     * to GAE's response size limits.
     * Because "bytes=x-y" requests bytes x through y _inclusive_,
     * this actually requests y - x + 1 bytes,
     * i.e. CHUNK_SIZE + 1 bytes
     * when x = 0 and y = CHUNK_SIZE.
     * This currently corresponds to laeproxy's RANGE_REQ_SIZE of 2000000.
     */
    public static final long CHUNK_SIZE = 2000000 - 1;
    
    public static final String GET_EXCEPTIONAL_API_KEY = 
        ExceptionalUtils.NO_OP_KEY;
    
    //public static final String LANTERN_JID = "lantern-controller@appspot.com";
    public static final String LANTERN_JID = "lanternctrl@appspot.com";
    
   
    public static final String VERSION_KEY = "v";
    
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
    
    
    /**
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

    public static final String INVITES_KEY = "invites";
    
    public static final String INVITED_EMAIL = "invem";
    
    public static final String INVITEE_NAME = "inv_name";
    
    public static final String INVITER_NAME = "invr_name";
    
    public static final String INVITED = "invd";
    
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
        new File(System.getProperty("user.home"), 
            ".config/autostart/lantern-autostart.desktop");

    public static final String CONNECT_ON_LAUNCH = "connectOnLaunch";

    public static final String START_AT_LOGIN = "startAtLogin";

    public static final File CONFIG_DIR = 
        new File(System.getProperty("user.home"), ".lantern");
    
    public static final File DEFAULT_MODEL_FILE = 
            new File(CONFIG_DIR, "model");
    
    /**
     * Note that we don't include the "X-" for experimental headers here. See:
     * the draft that appears likely to become an RFC at:
     * 
     * http://tools.ietf.org/html/draft-ietf-appsawg-xdash
     */
    public static final String LANTERN_VERSION_HTTP_HEADER_NAME = 
        "Lantern-Version";
    
    public static final String LANTERN_VERSION_HTTP_HEADER_VALUE = VERSION;
    
    public static File DATA_DIR;
    
    public static File LOG_DIR;

    public static final boolean ON_APP_ENGINE;

    public static final int KSCOPE_ADVERTISEMENT = 0x2111;
    public static final String KSCOPE_ADVERTISEMENT_KEY = "ksak";

    public static final Charset UTF8 = Charset.forName("UTF8");

    static {
        boolean tempAppEngine;
        try {
            Class.forName("org.lantern.LanternControllerUtils");
            DATA_DIR = null;
            LOG_DIR = null;
            tempAppEngine = true;
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

            tempAppEngine = false;
        }
        
        ON_APP_ENGINE = tempAppEngine;
    }
}
