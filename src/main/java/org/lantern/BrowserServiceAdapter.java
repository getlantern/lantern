package org.lantern;

import java.net.URI;
import java.net.URISyntaxException;

import org.lantern.state.StaticSettings;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Base class for implementors of {@link BrowserService} that encapsulates
 * common stuff. Sub-classes just need to implement
 * {@link BrowserService#openBrowser(URI)}.
 */
public abstract class BrowserServiceAdapter implements BrowserService {
    protected final Logger log = LoggerFactory.getLogger(getClass());

    @Override
    public void openBrowser() {
        openBrowser(StaticSettings.getApiPort(), StaticSettings.getPrefix());
    }

    @Override
    public void openBrowser(int port, String prefix) {
        String uri = StaticSettings.getLocalEndpoint(port, prefix)
                + "/index.html";
        try {
            openBrowser(new URI(uri));
        } catch (URISyntaxException use) {
            log.error("Unable to parse uri: {}", uri, use);
        }
    }

    @Override
    public final void openBrowserWhenPortReady() {
        final int port = StaticSettings.getApiPort();
        final String prefix = StaticSettings.getPrefix();
        log.info("Waiting on port: " + port);
        openBrowserWhenPortReady(port, prefix);
    }

    @Override
    public final void openBrowserWhenPortReady(final int port,
            final String prefix) {
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
    public void reopenBrowser() {
        // We don't control the browser process, so just open it again.
        openBrowser();
    }
}
