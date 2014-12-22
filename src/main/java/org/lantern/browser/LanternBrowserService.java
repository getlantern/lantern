package org.lantern.browser;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.lang3.SystemUtils;
import org.lantern.LanternUtils;
import org.lantern.Launcher;
import org.lantern.MessageService;
import org.lantern.state.Model;
import org.lantern.state.StaticSettings;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * This class handles opening a browser on the user's operating system to the
 * Lantern user interface.
 */
@Singleton
public class LanternBrowserService implements BrowserService {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private static final int SCREEN_WIDTH = 970;
    private static final int SCREEN_HEIGHT = 630;
    
    private final LanternBrowser browser;
    private final MessageService messageService;
    private final AtomicReference<Process> process = 
            new AtomicReference<Process>();

    @Inject
    public LanternBrowserService(final MessageService messageService,
            final Model model) {
        this.messageService = messageService;
        if (SystemUtils.IS_OS_WINDOWS) {
            this.browser = new WindowsBrowser(SCREEN_WIDTH, SCREEN_HEIGHT);
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            this.browser = new OsxBrowser();
        } else if (SystemUtils.IS_OS_LINUX) {
            this.browser = new UbuntuBrowser(SCREEN_WIDTH, SCREEN_WIDTH);
        } else {
            log.error("Platform not supported");
            throw new UnsupportedOperationException("Platform not supported");
        }
    }
    
    /**
     * Opens the browser.
     */
    private void openBrowser() {
        openBrowser(StaticSettings.getApiPort(), StaticSettings.getPrefix());
    }
    
    /**
     * Opens the browser.
     * @param port 
     */
    private void openBrowser(final int port, final String prefix) {
        final Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                launchBrowser(port, prefix);
            }
        }, "Chrome-Browser-Launch-Thread");
        t.setDaemon(true);
        t.start();
    }

    private void launchBrowser(final int port, final String prefix) {
        log.info("Launching browser...");
        // If there's an existing process for any reason, make sure it's exited
        // before opening a new one.
        if (this.process.get() != null) {
            try {
                final int exitValue = this.process.get().exitValue();
                log.info("Got exit value from former process: ", exitValue);
            } catch (final IllegalThreadStateException e) {
                // This indicates the existing process is still running.
                log.info("Ignoring open call since process is still running");
                return;
            }
        }
        final String endpoint = StaticSettings.getLocalEndpoint(port, prefix);
        log.info("Opening browser to: {}", endpoint);
        
        final String uri = endpoint + "/index.html";
        try {
            this.process.set(this.browser.open(uri));
        } catch (final IOException e) {
            log.error("Could not open chrome?", e);
        } catch (final UnsupportedOperationException e) {
            this.messageService.showMessage("Chrome Required", 
                "We're sorry, but Lantern requires you to have Google Chrome " +
                "to run successfully. You can download Google Chrome from " +
                "<a href='https://www.google.com/chrome/'>https://www.google.com/chrome/</a>. Once Chrome is installed, " +
                "please restart Lantern.");
            log.info("Lantern requires Google Chrome, exiting");
            System.exit(0);
        }
    }
    
    @Override
    public void openBrowserWhenPortReady() {
        final int port = StaticSettings.getApiPort();
        final String prefix = StaticSettings.getPrefix();
        log.debug("Waiting on port: "+port);
        openBrowserWhenPortReady(port, prefix);
    }
    
    private void openBrowserWhenPortReady(final int port, final String prefix) {
        log.debug("Waiting for server...");
        final long start = System.currentTimeMillis();
        LanternUtils.waitForServer(port);
        log.debug("Server is running. Opening browser on port: {} WAITED FOR " +
            "SERVER FOR {} ms", port, System.currentTimeMillis() - start);
        log.debug("OPENING BROWSER AFTER {} OF TOTAL START TIME...", 
            System.currentTimeMillis() - Launcher.START_TIME);
        openBrowser(port, prefix);
    }

    @Override
    public void start() {
    }

    @Override
    public void stop() {
        log.info("Closing Lantern browser...process is: {}", process);
        if (process.get() != null) {
            log.info("Really closing Chrome browser...");
            process.get().destroy();
        }
        this.process.set(null);
    }

    @Override
    public void reopenBrowser() {
        stop();
        openBrowser();
    }
}