package org.lantern;

import java.net.URI;

public interface BrowserService {

    void openBrowser();

    void openBrowser(int port, final String prefix);

    void openBrowser(URI uri);

    void openBrowserWhenPortReady(int port, final String prefix);

    void openBrowserWhenPortReady();

    void reopenBrowser();

}
