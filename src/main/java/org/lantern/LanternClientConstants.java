package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Properties;

import org.apache.commons.lang3.SystemUtils;
import org.lantern.exceptional4j.ExceptionalUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Client-side constants.
 */
public class LanternClientConstants {
    private static final Logger LOG =
        LoggerFactory.getLogger(LanternClientConstants.class);

    public static final String FALLBACK_SERVER_HOST;
    public static final String FALLBACK_SERVER_PORT;

    private static final boolean isDevMode;

    /**
     * This is the version of Lantern we're running. This is automatically
     * replaced when we push new releases. Don't change this directly; the
     * installer will update it.
     */
    public static final String VERSION;

    static {
        final String host = "fallback_server_host_tok";
        final String port = "fallback_server_port_tok";
        FALLBACK_SERVER_HOST = host.endsWith("_tok") ? "75.101.134.244" : host;
        FALLBACK_SERVER_PORT = port.endsWith("_tok") ? "7777" : port;
        Properties prop = new Properties();
        try {
            ClassLoader classLoader = LanternClientConstants.class.getClassLoader();
            prop.load(classLoader.getResourceAsStream("lantern-version.properties"));
        } catch (IOException e) {
            LOG.warn("Could not load version properties file : ", e);
        } finally {
            final String version = prop.getProperty("lantern.version");
            if (version.equals("${project.version}")) {
                VERSION = "0.0.1-SNAPSHOT";
            } else {
                VERSION = version + "-" + prop.getProperty("git.commit.id");
            }
            isDevMode = VERSION.contains("-SNAPSHOT");
        }
    }
    public static final String FALLBACK_SERVER_USER = "fallback_server_user_tok";
    public static final String FALLBACK_SERVER_PASS = "fallback_server_pass_tok";

    public static final File DATA_DIR;

    public static final File LOG_DIR;
    
    public static final File CONFIG_DIR =
        new File(System.getProperty("user.home"), ".lantern");

    public static final File DEFAULT_MODEL_FILE =
            new File(CONFIG_DIR, "model");

    public static final File DEFAULT_TRANSFERS_FILE =
            new File(CONFIG_DIR, "transfers");

    public static final File TEST_PROPS =
            new File(CONFIG_DIR, "test.properties");
    
    public static final File TEST_PROPS2 =
            new File(SystemUtils.USER_DIR, "src/test/resources/test.properties");
    
    public static final long START_TIME = System.currentTimeMillis();
    

    public static final int SYNC_INTERVAL_SECONDS = 6;
    
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
    

    public static final String GET_EXCEPTIONAL_API_KEY =
        ExceptionalUtils.NO_OP_KEY;
    
    static {
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
    }
    
    public static final File GEOIP = new File(DATA_DIR, "GeoIP.dat");
    
    public static final String LANTERN_VERSION_HTTP_HEADER_VALUE = VERSION;
    public static final String LOCALHOST = "127.0.0.1";
    public static final long CONNECTIVITY_UPDATE_INTERVAL = 120 * 1000;

    // Not final because it may be set from the command line for debugging.
    public static String LANTERN_JID;

    // Not final because it may be set from the command line for debugging.
    public static String STATS_URL;

    private static long recentProxyTimeout = 60 * 1000;

    public static void setControllerId(final String id) {
        LANTERN_JID = id + "@appspot.com";
        STATS_URL = "https://" + id + ".appspot.com/stats";
    }

    static {
        setControllerId("lanternctrl");
    }

    public static long getRecentProxyTimeout() {
        return recentProxyTimeout;
    }

    public static void setRecentProxyTimeout(long timeout) {
        recentProxyTimeout  = timeout;
    }

    public static boolean isDevMode() {
        return isDevMode;
    }
}
