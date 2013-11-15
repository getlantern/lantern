package org.lantern;

import java.awt.Desktop;
import java.io.IOException;
import java.net.URI;

import com.google.inject.Singleton;

/**
 * A {@link BrowserService} that opens links in the system's default browser.
 */
@Singleton
public class SystemDefaultBrowserService extends BrowserServiceAdapter {
    @Override
    public void openBrowser(URI uri) {
        log.debug("Opening browser to: {}", uri);
        try {
            Desktop.getDesktop().browse(uri);
        } catch (IOException ioe) {
            log.error("Unable to browse to uri: {}", uri, ioe);
        }
    }
}
