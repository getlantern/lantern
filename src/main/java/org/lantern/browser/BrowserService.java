package org.lantern.browser;

import org.lantern.LanternService;


public interface BrowserService extends LanternService {

    void openBrowser();

    void openBrowser(int port, final String prefix);

    void openBrowserWhenPortReady(int port, final String prefix);

    void openBrowserWhenPortReady();

    void reopenBrowser();

}
