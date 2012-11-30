package org.lantern;

import java.io.IOException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ChromeBrowserService implements BrowserService {

    private final Logger log = LoggerFactory.getLogger(getClass());
    private ChromeRunner chrome;
    
    /**
     * Opens the browser.
     */
    @Override
    public void openBrowser() {
        try {
            this.chrome = new ChromeRunner();
        } catch (final IOException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        final Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                //buildBrowser();
                launchChrome();
            }
        }, "Chrome-Browser-Launch-Thread");
        t.setDaemon(true);
        t.start();
    }
    
    private void launchChrome() {
        try {
            this.chrome.open();
        } catch (IOException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
        } catch (InterruptedException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
    }
    
    @Override
    public void openBrowserWhenPortReady() {
        openBrowserWhenPortReady(RuntimeSettings.getApiPort());
    }
    
    @Override
    public void openBrowserWhenPortReady(final int port) {
        System.out.println("WAITING FOR BROWSER ON PORT: "+port);
        LanternUtils.waitForServer(port);
        log.info("Server is running. Opening browser...");
        openBrowser();
    }

    @Override
    public void start() {
        // Does nothing in this case...
    }

    @Override
    public void stop() {
        if (this.chrome != null) {
            this.chrome.close();
        }
    }
}
