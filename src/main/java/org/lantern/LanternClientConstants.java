package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Properties;

import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Client-side constants.
 */
public class LanternClientConstants {
    private static final Logger LOG =
        LoggerFactory.getLogger(LanternClientConstants.class);

    private static final boolean isDevMode;

    /**
     * This is the version of Lantern we're running. This is automatically
     * replaced when we push new releases. Don't change this directly; the
     * installer will update it.
     */
    public static final String VERSION;
    
    public static final String GIT_VERSION;
    
    public static final String BUILD_TIME;
    
    public static final String LOG4J_PROPS_PATH = "src/main/resources/log4j.properties";

    public static final String LOG4J_PROPS_NAME = "log4j.properties";

    static {
        final Properties prop = new Properties();
        try {
            final ClassLoader cl = 
                LanternClientConstants.class.getClassLoader();
            prop.load(cl.getResourceAsStream("lantern-version.properties"));
            GIT_VERSION = prop.getProperty("git.commit.id").substring(0, 7);
            final String version = prop.getProperty("lantern.version");
            
            // Project version not always substituted in tests.
            if (version.equals("${project.version}")) {
                VERSION = "0.0.1-SNAPSHOT";
                isDevMode = true;
                BUILD_TIME = "1969-01-01";
            } else {
                final File props = new File(LOG4J_PROPS_PATH);
                isDevMode = props.isFile();
                VERSION = version + "-" + GIT_VERSION;
                BUILD_TIME = prop.getProperty("git.build.time");
            }
        } catch (final IOException e) {
            LOG.warn("Could not load version properties file : ", e);
            throw new Error("Could not load version props?", e);
        }
    }

    public static final File DATA_DIR;

    public static final File LOG_DIR;

    public static final File CONFIG_DIR =
        new File(System.getProperty("user.home"), ".lantern");

    public static final File DEFAULT_MODEL_FILE =
            new File(CONFIG_DIR, "model-0.0.5");

    public static final File DEFAULT_TRANSFERS_FILE =
            new File(CONFIG_DIR, "transfers");

    public static final File TEST_PROPS =
            new File(CONFIG_DIR, "test.properties");

    public static final File TEST_PROPS2 =
            new File(SystemUtils.USER_DIR, "src/test/resources/test.properties");

    public static final long START_TIME = System.currentTimeMillis();

    public static final int SYNC_INTERVAL_SECONDS = 6;
    
    public static volatile boolean FORCE_FLASHLIGHT = false;

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

    public static final String LANTERN_VERSION_HTTP_HEADER_VALUE = VERSION;
    public static final String LOCALHOST = "127.0.0.1";
    public static final long CONNECTIVITY_UPDATE_INTERVAL = 120 * 1000;
    public static final int ASYNC_APPENDER_BUFFER_SIZE = 1024;


    // Not final because it may be set from the command line for debugging.
    public static String LANTERN_JID;

    public static String CONTROLLER_URL;

    public static void setControllerId(final String id) {
        if (StringUtils.isBlank(id)) {
            LOG.warn("Blank controller id?");
            return;
        }
        LANTERN_JID = id + "@appspot.com";
        CONTROLLER_URL = "https://" + id + ".appspot.com";
    }

    static {
        setControllerId(S3Config.DEFAULT_CONTROLLER_ID);
    }

    public static boolean isDevMode() {
        return isDevMode;
    }
}
