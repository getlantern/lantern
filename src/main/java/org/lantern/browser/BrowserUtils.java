package org.lantern.browser;

import java.awt.Desktop;
import java.awt.Point;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URI;
import java.util.List;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
import org.lantern.win.Registry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Browser utility functions.
 */
public class BrowserUtils {
    
    private final static Logger LOG = LoggerFactory.getLogger(BrowserUtils.class);
    
    private BrowserUtils(){}

    /**
     * Adds the various default arguments to chrome.
     * 
     * @param commands The list of commands to add arguments to.
     * @param windowWidth The desired window width.
     * @param windowHeight The desired window height.
     */
    public static void addDefaultChromeArgs(final List<String> commands) {
        commands.add("--disable-translate");
        commands.add("--disable-sync");
        commands.add("--no-default-browser-check");
        commands.add("--disable-metrics");
        commands.add("--disable-metrics-reporting");
        commands.add("--temp-profile");
        commands.add("--no-first-run");
        commands.add("--disable-plugins");
        commands.add("--disable-java");
        commands.add("--disable-extensions");
    }
    
    /**
     * Adds arguments to make chrome as app-like as possible.
     * 
     * @param commands The list of commands to add arguments to.
     * @param windowWidth The desired window width.
     * @param windowHeight The desired window height.
     * @param uri The URI to open in the browser.
     */
    public static void addAppWindowArgs(final List<String> commands, 
            final int windowWidth, final int windowHeight, final String uri) {
        
        // We need to use a custom data directory because if we
        // don't the process ID we get back will correspond with
        // something other than the process we need to kill, causing
        // the window not to close. Not sure why, but that's what
        // happens.
        // See http://peter.sh/experiments/chromium-command-line-switches/
        commands.add("--user-data-dir="
                + LanternClientConstants.CONFIG_DIR.getAbsolutePath());
        commands.add("--window-size=" + windowWidth + "," + windowHeight);
        
        final Point location = 
                LanternUtils.getScreenCenter(windowWidth, windowHeight);
        commands.add("--window-position=" + location.x + "," + location.y);
        commands.add("--new-window");
        commands.add("--app=" + uri);
    }
    
    /**
     * Opens the specified URL in the operating system's default browser. 
     * This does not return the process ID of the new window and therefore
     * cannot be used if the caller needs to ever close the window.
     * 
     * @param uri The URI to open.
     */
    public static void openSystemDefaultBrowser(final String uri) {
        LOG.debug("Opening system default browser to: {}", uri);
        try {
            Desktop.getDesktop().browse(new URI(uri));
        } catch (final Exception e) {
            LOG.error("Unable to browse to uri: {}", uri, e);
        }
    }
    
    /**
     * Checks if FireFox is the user's default browser on Windows. As of this
     * writing, this is only tested on Windows 8.1 but should theoretically
     * work on other Windows versions as well.
     * 
     * @return <code>true</code> if Firefox is the user's default browser,
     * otherwise <code>false</code>.
     */
    public static boolean firefoxOrChromeIsDefaultBrowser() {
        if (!SystemUtils.IS_OS_WINDOWS) {
            return false;
        }
        final String key = "Software\\Microsoft\\Windows\\Shell\\Associations"
                + "\\UrlAssociations\\http\\UserChoice";
        final String name = "ProgId";
        final String result = Registry.read(key, name);
        if (StringUtils.isBlank(result)) {
            LOG.error("Could not find browser registry entry on: {}, {}", 
                SystemUtils.OS_NAME, SystemUtils.OS_VERSION);
            return false;
        }
        final String norm = result.toLowerCase();
        return norm.contains("firefox") || norm.contains("chrome");
    }

    /**
     * Runs the process specified in the given list of commands.
     * 
     * @param commands The list of commands to run.
     * @return The process.
     * @throws IOException If there's an error running the commands.
     */
    public static Process runProcess(final List<String> commands) throws IOException {
        final ProcessBuilder processBuilder = new ProcessBuilder(commands);

        // Note we don't call waitFor on the process to avoid blocking the
        // calling thread and because we don't care too much about the return
        // value.
        final Process process = processBuilder.start();
        LOG.info("Started process!!!");
            
        new Analyzer(process.getInputStream());
        new Analyzer(process.getErrorStream());
        return process;
    }
    

    private static class Analyzer implements Runnable {

        final InputStream is;

        public Analyzer(final InputStream is) {
            this.is = is;
            final Thread t = new Thread(this, "Browser-Process-Output-Thread");
            t.setDaemon(true);
            t.start();
        }

        @Override
        public void run() {
            BufferedReader br = null;
            try {
                br = new BufferedReader(new InputStreamReader(this.is, 
                    LanternConstants.UTF8));

                String line = "";
                while((line = br.readLine()) != null) {
                    System.out.println(line);
                }
            } catch (final IOException e) {
                LOG.info("Exception reading external process", e);
            } finally {
                IOUtils.closeQuietly(br);
            }
            
        }
    }
}
