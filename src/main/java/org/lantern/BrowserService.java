package org.lantern;

public interface BrowserService extends LanternService {

    void openBrowser();

    void openBrowser(int port, final String prefix);

    void openBrowserWhenPortReady(int port, final String prefix);

    void openBrowserWhenPortReady();
    
    void reopenBrowser();

}
