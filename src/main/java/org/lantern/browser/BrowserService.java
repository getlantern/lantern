package org.lantern.browser;

import org.lantern.LanternService;

/**
 * Interface for interacting with the browser.
 */
public interface BrowserService extends LanternService {

    void openBrowserWhenPortReady();

    void reopenBrowser();

}
