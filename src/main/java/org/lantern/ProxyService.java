package org.lantern;

import java.io.File;

import org.lantern.Proxifier.ProxyConfigurationError;

/**
 * Interface for controlling the OS-level system proxy settings.
 */
public interface ProxyService {

    void startProxying() throws ProxyConfigurationError;

    void startProxying(boolean force, File pacFile)
            throws ProxyConfigurationError;

    void proxyAllSites(boolean proxyAll) throws ProxyConfigurationError;

    void stopProxying() throws ProxyConfigurationError;

    void refresh();

    void proxyGoogle();

}
