package org.lantern;

import java.io.IOException;

import org.lantern.state.StaticSettings;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Singleton;

@Singleton
public class ChromeBrowserService implements BrowserService {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    
    private static final int SCREEN_WIDTH = 970;
    private static final int SCREEN_HEIGHT = 630;
    
    private final ChromeRunner chrome = 
            new ChromeRunner(SCREEN_WIDTH, SCREEN_HEIGHT);
    
    /**
     * Opens the browser.
     */
    @Override
    public void openBrowser() {
        final Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                //buildBrowser();
                launchChrome(StaticSettings.getApiPort(), StaticSettings.getPrefix());
            }
        }, "Chrome-Browser-Launch-Thread");
        t.setDaemon(true);
        t.start();
    }
    
    /**
     * Opens the browser.
     * @param port 
     */
    @Override
    public void openBrowser(final int port, final String prefix) {
        final Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                //buildBrowser();
                launchChrome(port, prefix);
            }
        }, "Chrome-Browser-Launch-Thread");
        t.setDaemon(true);
        t.start();
    }

    private void launchChrome(final int port, final String prefix) {
        log.info("Launching chrome...");
        try {
            this.chrome.open(port, prefix);
        } catch (final IOException e) {
            log.error("Could not open chrome?", e);
        }
    }
    
    @Override
    public void openBrowserWhenPortReady() {
        final int port = StaticSettings.getApiPort();
        final String prefix = StaticSettings.getPrefix();
        log.info("Waiting on port: "+port);
        openBrowserWhenPortReady(port, prefix);
    }
    
    @Override
    public void openBrowserWhenPortReady(final int port, final String prefix) {
        LanternUtils.waitForServer(port);
        log.info("Server is running. Opening browser on port: {}", port);
        openBrowser(port, prefix);
    }

    @Override
    public void start() {
    }

    @Override
    public void stop() {
        if (this.chrome != null) {
            this.chrome.close();
        }
    }

    @Override
    public void reopenBrowser() {
        stop();
        openBrowser();
    }
}
