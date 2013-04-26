package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;

import org.apache.commons.lang.SystemUtils;
import org.eclipse.swt.SWT;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.event.ProxyConnectionEvent;
import org.lantern.event.QuitEvent;
import org.lantern.event.ResetEvent;
import org.lantern.event.SetupCompleteEvent;
import org.lantern.state.Connectivity;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;
import org.lantern.state.StaticSettings;
import org.lantern.state.SyncPath;
import org.lantern.win.WinProxy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.common.io.Files;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class that handles turning proxying on and off for all platforms.
 */
@Singleton
public class Proxifier implements ProxyService, LanternService {
    
    public class ProxyConfigurationError extends Exception {}
    public class ProxyConfigurationCancelled extends ProxyConfigurationError {};
    
    private final Logger LOG = LoggerFactory.getLogger(getClass());
    
    /**
     * File external processes can use to determine if Lantern is currently
     * proxying traffic. Useful for things like the FireFox extensions.
     * (XXX necessary? https://github.com/getlantern/lantern/issues/678)
     */
    private final File LANTERN_PROXYING_FILE =
        new File(LanternClientConstants.CONFIG_DIR, "lanternProxying");
    
    private boolean interactiveUnproxyCalled;

    public final static File PROXY_ON = 
        new File(LanternClientConstants.CONFIG_DIR, "proxy_on.pac");
    public final static File PROXY_OFF = 
        new File(LanternClientConstants.CONFIG_DIR, "proxy_off.pac");
    public final static File PROXY_GOOGLE = 
            new File(LanternClientConstants.CONFIG_DIR, "proxy_google.pac");
    public final static File PROXY_ALL = 
        new File(LanternClientConstants.CONFIG_DIR, "proxy_all.pac");

    private final WinProxy WIN_PROXY = 
        new WinProxy(LanternClientConstants.CONFIG_DIR);
    
    private final MessageService messageService;

    private final ModelUtils modelUtils;

    private final Model model;

    private ProxyConnectionEvent lastProxyConnectionEvent;

    private final ProxyTracker proxyTracker;

    @Inject 
    public Proxifier(final MessageService messageService,
        final ModelUtils modelUtils, final Model model, 
        final ProxyTracker proxyTracker) {
        this.messageService = messageService;
        this.modelUtils = modelUtils;
        this.model = model;
        this.proxyTracker = proxyTracker;
        copyFromLocal(PROXY_ON);
        copyFromLocal(PROXY_ALL);
        copyFromLocal(PROXY_OFF);
        Events.register(this);
        
        LANTERN_PROXYING_FILE.delete();
        LANTERN_PROXYING_FILE.deleteOnExit();
        if (!PROXY_OFF.isFile()) {
            final String msg = 
                "No pac at: "+PROXY_OFF.getAbsolutePath() +"\nfrom: " +
                new File(".").getAbsolutePath();
            LOG.error(msg);
            throw new IllegalStateException(msg);
        }
        LOG.debug("Both pac files are in their expected locations");
    }
    
    @Subscribe
    public void onQuit(final QuitEvent quit) {
        LOG.debug("Got quit event!");
        interactiveUnproxy();
    }
    
    /**
     * Synchronized setup complete handler because it has to coordinate with
     * proxy connection events. This is designed so either the setup complete
     * event or the proxy connection event can happen first.
     * 
     * @param event The setup complete event.
     */
    @Subscribe
    public synchronized void onSetupComplete(final SetupCompleteEvent event) {
        LOG.debug("Got setup complete!");
        if (this.lastProxyConnectionEvent != null && this.proxyTracker.hasProxy()) {
            LOG.debug("Re-firing last proxy connection event...");
            onProxyConnection(this.lastProxyConnectionEvent);
        } else {
            LOG.debug("No proxy connection event to refire or no proxy {}, {}", 
                this.lastProxyConnectionEvent, this.proxyTracker.hasProxy());
        }
    }
    
    /**
     * Synchronized proxy connection event handler because it has to sync up
     * with setup complete events (see above). This is designed so either 
     * the setup complete event or the proxy connection event can happen first.
     * 
     * @param pce The proxy connection event.
     */
    @Subscribe
    public synchronized void onProxyConnection(final ProxyConnectionEvent pce) {
        this.lastProxyConnectionEvent = pce;
        if (!model.isSetupComplete()) {
            LOG.debug("Ingoring proxy connection call when setup is not complete");
            return;
        }
        final ConnectivityStatus stat = pce.getConnectivityStatus();
        switch (stat) {
        case CONNECTED:
            LOG.debug("Got connected event");
            if (modelUtils.shouldProxy()) {
                try {
                    startProxying();
                } catch (final ProxyConfigurationError e) {
                    LOG.warn("Could not proxy?", e);
                }
            } else {
                LOG.debug("Ignoring proxy call! System proxy? "+
                        model.getSettings().isSystemProxy()+" get mode? "+
                        this.model.getSettings().getMode());
            }
            break;
        case CONNECTING:
            LOG.debug("Got connecting event");
            break;
        case DISCONNECTED:
            LOG.debug("Got disconnected event");
            try {
                stopProxying();
            } catch (final ProxyConfigurationError e) {
                LOG.warn("Could not unproxy?", e);
            }
            break;
        default:
            break;
        
        }
    }

    @Override
    public void start() throws Exception {
        // Nothing to do in this case;
    }

    @Override
    public void stop() {
        interactiveUnproxy();
    }
    
    private void copyFromLocal(final File dest) {
        final File local = new File(dest.getName());
        if (!local.isFile()) {
            LOG.error("No file at: {}", local);
            return;
        }
        if (!dest.getParentFile().isDirectory()) {
            LOG.error("No directory at: {}", dest.getParentFile());
            return;
        }
        try {
            Files.copy(local, dest);
        } catch (final IOException e) {
            LOG.error("Error copying file from "+local+" to "+ dest, e);
        }
    }
    
    /**
     * Configures Lantern to proxy all sites, not just the ones on the 
     * whitelist.
     * 
     * @param proxyAll Whether or not to proxy all sites.
     * @throws ProxyConfigurationError If there's an error configuring the 
     * proxy.
     */
    @Override
    public void proxyAllSites(final boolean proxyAll) 
        throws ProxyConfigurationError {
        if (proxyAll) {
            startProxying(true, PROXY_ALL);
        } else {
            // In this case the user is still in GET mode (in order to have that
            // option available at all), so we need to go back to proxying
            // using the normal pac file.
            startProxying(true, PROXY_ON);
        }
    }

    /**
     * This method is private because it should only be called in response to
     * proxy connection events and setup complete events.
     * 
     * @throws ProxyConfigurationError If there's an error configuring the
     * proxy.
     */
    private void startProxying() throws ProxyConfigurationError {
        if (this.model.getSettings().isProxyAllSites()) {
            // If we were previously configured to proxy all sites, then we
            // need to force the override.
            startProxying(true, PROXY_ALL);
        } else {
            startProxying(false, PROXY_ON);
        }
    }
    
    @Override
    public void startProxying(final boolean force, final File pacFile) 
        throws ProxyConfigurationError {
        if (isProxying() && !force) {
            LOG.debug("Already proxying!");
            return;
        }
        
        if (!modelUtils.shouldProxy()) {
            LOG.debug("Not proxying in current mode...{}", pacFile);
            final String url = getPacFileUrl(pacFile);
            final Connectivity connectivity = this.model.getConnectivity();
            connectivity.setPacUrl(url);
            Events.sync(SyncPath.CONNECTIVITY, connectivity);
            return;
        }

        LOG.debug("Starting to proxy!");
        // Always update the pac file to make sure we've got all the latest
        // entries -- only recreates proxy_on.
        if (pacFile.equals(PROXY_ON)) {
            PacFileGenerator.generatePacFile(
                this.model.getSettings().getWhitelist().getEntriesAsStrings(), 
                PROXY_ON);
        }
        
        LOG.debug("Autoconfiguring local to proxy Lantern");
        final String url = getAndSetPacFileUrl(pacFile);
        
        if (SystemUtils.IS_OS_MAC_OSX) {
            proxyOsx(url);
        } else if (SystemUtils.IS_OS_WINDOWS) {
            proxyWindows(url);
        } else if (SystemUtils.IS_OS_LINUX) {
            proxyLinux(url);
        }
        Events.syncModel(this.model);
        // success
        try {
            if (!LANTERN_PROXYING_FILE.isFile() &&
                !LANTERN_PROXYING_FILE.createNewFile()) {
                LOG.error("Could not create proxy file?");
            }
        } catch (final IOException e) {
            LOG.error("Could not create proxy file?", e);
        }
    }
    
    public void interactiveUnproxy() {
        if (interactiveUnproxyCalled) {
            LOG.debug("Interactive unproxy already called!");
            return;
        }
        interactiveUnproxyCalled = true;
        if (!model.getSettings().isUiEnabled()) {
            try {
                stopProxying();
            } catch (final Proxifier.ProxyConfigurationError e) {
                LOG.error("Failed to unconfigure proxy: {}", e);
            }
        } else {
            // The following often happens as the result of the quit event
            // because we need the UI to still be up to interact with the 
            // user -- that's not always the case with System.exit/shutdown
            // hooks.
            boolean finished = false;
            while (!finished) {
                try {
                    stopProxying();
                    finished = true;
                } catch (final Proxifier.ProxyConfigurationError e) {
                    LOG.error("Failed to unconfigure proxy.");
                    // XXX i18n
                    final String question = "Failed to change the system proxy settings.\n\n" + 
                    "If Lantern remains as the system proxy after being shut down, " + 
                    "you will need to manually change the system's network proxy settings " + 
                    "in order to access the web.\n\nTry again?";
                    
                    // TODO: Don't think this will work on Linux.
                    final int response = 
                        messageService.askQuestion("Proxy Settings", question,
                        SWT.APPLICATION_MODAL | SWT.ICON_WARNING | SWT.RETRY | SWT.CANCEL);
                    if (response == SWT.CANCEL) {
                        finished = true;
                    }
                    else {
                        LOG.debug("Trying again");
                    }
                }
            }
        }
    }

    @Override
    public void stopProxying() throws ProxyConfigurationError {
        if (!isProxying()) {
            LOG.debug("Ignoring call since we're not proxying");
            return; 
        }

        LOG.debug("Unproxying Lantern");
        LANTERN_PROXYING_FILE.delete();
        if (SystemUtils.IS_OS_MAC_OSX) {
            unproxyOsx();
        } else if (SystemUtils.IS_OS_WINDOWS) {
            unproxyWindows();
        } else if (SystemUtils.IS_OS_LINUX) {
            unproxyLinux();
        }
    }

    public boolean isProxying() {
        return LANTERN_PROXYING_FILE.isFile();
    }
    
    private void proxyLinux(final String url) 
        throws ProxyConfigurationError {
        //final String path = url.toURI().toASCIIString();

        // TODO: what if the user has spaces in their user name? does the 
        // URL-encoding of the path make the pac file config fail?
        try {
            final String result1 = 
                LanternUtils.runCommand("gsettings", "set", "org.gnome.system.proxy", 
                    "mode", "'auto'");
            LOG.debug("Result of Ubuntu gsettings mode call: {}", result1);
            final String result2 = 
                LanternUtils.runCommand("gsettings", "set", "org.gnome.system.proxy", 
                    "autoconfig-url", url);
            LOG.debug("Result of Ubuntu gsettings pac file call: {}", result2);
        } catch (final IOException e) {
            LOG.warn("Error calling Ubuntu proxy script!", e);
            throw new ProxyConfigurationError();
        }
    }
    
    private void proxyOsx(final String url) 
        throws ProxyConfigurationError {
        configureOsxProxyViaScript(true, url);
    }
    
    private void configureOsxProxyViaScript(final boolean proxy,
        final String url) throws ProxyConfigurationError {
        final String onOrOff;
        if (proxy) {
            onOrOff = "on";
        } else {
            onOrOff = "off";
        }
        
        try {
            final String result = LanternUtils.runCommand("./configureNetworkServices", onOrOff, url);
            LOG.debug("Result of command is {}", result);
        } catch (final IOException e) {
            LOG.debug("Exception running script", e);
            throw new ProxyConfigurationCancelled();
        }
    }

    private void proxyWindows(final String url) {
        if (!SystemUtils.IS_OS_WINDOWS) {
            LOG.debug("Not running on Windows");
            return;
        }
        

        // Note we don't use toURI().toASCIIString here because the URL encoding
        // of spaces causes problems.
        //final String url = "file://"+pacFile.getAbsolutePath();
            //ACTIVE_PAC.toURI().toASCIIString().replace("file:/", "file://");
        LOG.debug("Using pac path: {}", url);
        
        WIN_PROXY.setPacFile(url);
    }

    protected void unproxyWindows() {
        LOG.info("Unproxying windows");
        WIN_PROXY.unproxy();
    }
    
    private void unproxyLinux() throws ProxyConfigurationError {
        try {
            final String result1 = 
                LanternUtils.runCommand("gsettings", "set", "org.gnome.system.proxy", 
                    "mode", "'none'");
            LOG.debug("Result of Ubuntu gsettings mode call: {}", result1);
            final String result2 = 
                LanternUtils.runCommand("gsettings", "reset", "org.gnome.system.proxy", 
                    "autoconfig-url");
            LOG.debug("Result of Ubuntu gsettings pac file call: {}", result2);
        } catch (final IOException e) {
            LOG.warn("Error calling Ubuntu proxy script!", e);
            throw new ProxyConfigurationError();
        }
    }

    private void unproxyOsx() throws ProxyConfigurationError {
        // Note that this is a bit of overkill in that we both turn of the
        // PAC file-based proxying and set the PAC file to one that doesn't
        // proxy anything.
        configureOsxProxyViaScript(false, getPacFileUrl(PROXY_OFF));
    }
    
    private String getPacFileUrl(final File pacFile) {
        final String url = 
            StaticSettings.getLocalEndpoint()+"/"+
            pacFile.getName();
        return url;

    }

    private String getAndSetPacFileUrl(final File pacFile) {
        final String url = getPacFileUrl(pacFile);
        this.model.getConnectivity().setPacUrl(url);
        return url;
    }

    /**
     * This will refresh the proxy entries for things like new additions to
     * the whitelist.
     */
    @Override
    public void refresh() {
        if (isProxying()) {
            if (model.getSettings().isProxyAllSites()) {
                // If we were previously configured to proxy all sites, then we
                // need to force the override.
                try {
                    startProxying(true, PROXY_ALL);
                } catch (final ProxyConfigurationError e) {
                    LOG.warn("Could not proxy", e);
                }
            } else {
                try {
                    startProxying(true, PROXY_ON);
                } catch (final ProxyConfigurationError e) {
                    LOG.warn("Could not proxy", e);
                }
            }
        }
    }
    
    @Override
    public void proxyGoogle() {
        PacFileGenerator.generatePacFile(
            Arrays.asList("google.com", "youtube.com"), 
            Proxifier.PROXY_GOOGLE);
        
        try {
            startProxying(true, Proxifier.PROXY_GOOGLE);
        } catch (final ProxyConfigurationError e) {
            // Not too much we can do here if we're unable to set up the proxy.
            LOG.error("Could not proxy?", e);
        }
    }
    
    @Subscribe
    public void onReset(final ResetEvent event) {
        try {
            stopProxying();
        } catch (final ProxyConfigurationError e) {
            LOG.warn("Could not stop proxying", e);
        }
    }
    
    @Subscribe
    public void onModeChangedEvent(final ModeChangedEvent event) {
        switch (event.getNewMode()) {
        case get:
            LOG.debug("Nothing to do on roster when switched to get mode");
            return;
        case give:
            LOG.debug("Switched to give mode");
            try {
                stopProxying();
            } catch (final ProxyConfigurationError e) {
                LOG.debug("Error stopping proxying!", e);
            }
            break;
        case unknown:
            break;
        default:
            break;
        
        };
    }
}
