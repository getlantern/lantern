package org.lantern;

public interface BrowserService extends LanternService {

    void openBrowser();

    void openBrowserWhenPortReady(int port);

    void openBrowserWhenPortReady();

}
