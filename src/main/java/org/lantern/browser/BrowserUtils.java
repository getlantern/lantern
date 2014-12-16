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
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.LanternUtils;
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
    public static void addDefaultChromeArgs(final List<String> commands, 
            final int windowWidth, final int windowHeight) {
        
        // See http://peter.sh/experiments/chromium-command-line-switches/
        commands.add("--user-data-dir="
                + LanternClientConstants.CONFIG_DIR.getAbsolutePath());
        commands.add("--window-size=" + windowWidth + "," + windowHeight);
        
        final Point location = 
                LanternUtils.getScreenCenter(windowWidth, windowHeight);
        commands.add("--window-position=" + location.x + "," + location.y);
        commands.add("--disable-translate");
        commands.add("--disable-sync");
        commands.add("--no-default-browser-check");
        commands.add("--disable-metrics");
        commands.add("--disable-metrics-reporting");
        commands.add("--temp-profile");
        commands.add("--new-window");
        commands.add("--no-first-run");
        commands.add("--disable-plugins");
        commands.add("--disable-java");
        commands.add("--disable-extensions");
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
