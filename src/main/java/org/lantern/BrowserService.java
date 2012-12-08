package org.lantern;

public interface BrowserService extends LanternService {

    void openBrowser();

    void openBrowser(int port);
    
    void openBrowserWhenPortReady(int port);

    void openBrowserWhenPortReady();
    
    void reopenBrowser();

}
