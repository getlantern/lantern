package org.lantern.browser;

import java.io.IOException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Opens the lantern ui in a browser on OSX.
 */
public class OsxBrowser implements LanternBrowser {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    public Process open(final String uri) throws IOException {
        log.info("Opening browser to: {}", uri);
        BrowserUtils.openSystemDefaultBrowser(uri);
        return null;
    }
}
