package org.lantern.browser;

import java.io.IOException;

/**
 * Interface for operating-specific browsers that display the Lantern user
 * interface.
 */
public interface LanternBrowser {

    /**
     * Opens the URI to the Lantern user interface.
     * 
     * @param uri The URI to open.
     * @return The {@link Process} for the new browser, allowing the caller
     * to eventually close it, or <code>null</code> if a browser with an
     * associated process could not be created.
     * @throws IOException If there's an error opening the browser.
     */
    Process open(String uri) throws IOException;
}
