package org.lantern.browser;

import java.io.IOException;

public interface LanternBrowser {

    Process open(String uri) throws IOException;
}
