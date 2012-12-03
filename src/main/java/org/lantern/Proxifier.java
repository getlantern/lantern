package org.lantern;

import java.io.File;
import java.io.IOException;

import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.eclipse.swt.SWT;
import org.lantern.event.QuitEvent;
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
public class Proxifier implements LanternService {
    
    public class ProxyConfigurationError extends Exception {}
    public class ProxyConfigurationCancelled extends ProxyConfigurationError {};
    
    private final Logger LOG = 
        LoggerFactory.getLogger(Proxifier.class);
    
    /**
     * File external processes can use to determine if Lantern is currently
     * proxying traffic. Useful for things like the FireFox extensions.
     */
    private final File LANTERN_PROXYING_FILE =
        new File(LanternConstants.CONFIG_DIR, "lanternProxying");
    
    private boolean interactiveUnproxyCalled;

    private final MacProxyManager mpm = 
        new MacProxyManager("testId", 4291);
    
    public final static File PROXY_ON = 
        new File(LanternConstants.CONFIG_DIR, "proxy_on.pac");
    public final static File PROXY_OFF = 
        new File(LanternConstants.CONFIG_DIR, "proxy_off.pac");
    public final static File PROXY_ALL = 
        new File(LanternConstants.CONFIG_DIR, "proxy_all.pac");

    private final WinProxy WIN_PROXY = 
        new WinProxy(LanternConstants.CONFIG_DIR);
    
    private final MessageService messageService;
    
    @Inject public Proxifier(final MessageService messageService) {
        this.messageService = messageService;
        copyFromLocal(PROXY_ON);
        copyFromLocal(PROXY_ALL);
        copyFromLocal(PROXY_OFF);
        final class Subscriber {
            @Subscribe
            public void onQuit(final QuitEvent quit) {
                LOG.info("Got quit event!");
                interactiveUnproxy();
            }
        }
        Events.register(new Subscriber());
        
        if (SystemUtils.IS_OS_MAC_OSX) {
            final File Lantern = new File("Lantern");
            if (!Lantern.isFile()) {
                LOG.info("Creating hard link to osascript...");
                try {
                    final String result = 
                        mpm.runScript("ln", "/usr/bin/osascript", "Lantern");
                    LOG.info("Result of script is: {}", result);
                } catch (final IOException e) {
                    LOG.warn("Error creating hard link!!", e);
                }
            } else {
                LOG.info("Appears to already be a link to osascript");
            }
        }
        LANTERN_PROXYING_FILE.delete();
        LANTERN_PROXYING_FILE.deleteOnExit();
        if (!PROXY_OFF.isFile()) {
            final String msg = 
                "No pac at: "+PROXY_OFF.getAbsolutePath() +"\nfrom: " +
                new File(".").getAbsolutePath();
            LOG.error(msg);
            throw new IllegalStateException(msg);
        }
        LOG.info("Both pac files are in their expected locations");
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

    public void startProxying() throws ProxyConfigurationError {
        if (LanternHub.settings().isProxyAllSites()) {
            // If we were previously configured to proxy all sites, then we
            // need to force the override.
            startProxying(true, PROXY_ALL);
        } else {
            startProxying(false, PROXY_ON);
        }
    }
    
    private void startProxying(final boolean force, final File pacFile) 
        throws ProxyConfigurationError {
        if (isProxying() && !force) {
            LOG.info("Already proxying!");
            return;
        }
        
        if (!LanternUtils.shouldProxy()) {
            LOG.info("Not proxying in current mode...");
            return;
        }

        // Always update the pac file to make sure we've got all the latest
        // entries -- only recreates proxy_on.
        if (pacFile.equals(PROXY_ON)) {
            PacFileGenerator.generatePacFile(
                LanternHub.whitelist().getEntriesAsStrings(), PROXY_ON);
        }
        
        LOG.info("Autoconfiguring local to proxy Lantern");
        final String url = pacFileUrl(pacFile);
        
        if (SystemUtils.IS_OS_MAC_OSX) {
            proxyOsx(url);
        } else if (SystemUtils.IS_OS_WINDOWS) {
            proxyWindows(url);
        } else if (SystemUtils.IS_OS_LINUX) {
            proxyLinux(url);
        }
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
            LOG.info("Interactive unproxy already called!");
            return;
        }
        interactiveUnproxyCalled = true;
        if (!LanternHub.settings().isUiEnabled()) {
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
                        LOG.info("Trying again");
                    }
                }
            }
        }
    }

    public void stopProxying() throws ProxyConfigurationError {
        if (!isProxying()) {
            LOG.info("Ignoring call since we're not proxying");
            return; 
        }

        LOG.info("Unproxying Lantern");
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
                mpm.runScript("gsettings", "set", "org.gnome.system.proxy", 
                    "mode", "'auto'");
            LOG.info("Result of Ubuntu gsettings mode call: {}", result1);
            final String result2 = 
                mpm.runScript("gsettings", "set", "org.gnome.system.proxy", 
                    "autoconfig-url", url);
            LOG.info("Result of Ubuntu gsettings pac file call: {}", result2);
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
        
        boolean locked = false;
        try {
            locked = osxPrefPanesLocked();
        } catch (final IOException e) {
            locked = false;
        }
        
        // We create a random string for the pac file name to make sure all
        // browsers reload it.
        String applescriptCommand = 
            "do shell script \"./configureNetworkServices.bash "+ onOrOff + " "+url;
        
        if (locked) {
            applescriptCommand +="\" with administrator privileges without altering line endings";
        } else {
            applescriptCommand +="\" without altering line endings";
        }

        // XXX @myleshorton can we skip this when there's no need to change
        // system proxy settings, e.g. an unproxy call after a proxy call was
        // canceled, or vice versa?
        try {
            final String result = //mpm.runScript("osascript", "-e", applescriptCommand);
                mpm.runScript("./Lantern", "-e", applescriptCommand);
            LOG.info("Result of script is {}", result);
        } catch (final IOException e) {
            final String msg = e.getMessage();
            if (!msg.contains("canceled")) {
                // Could just be another language here...
                LOG.error("Script failure with unknown message: "+msg, e);
            } else {
                LOG.info("Exception running script", e);
            }
            LanternHub.settings().setSystemProxy(false);
            throw new ProxyConfigurationCancelled();
        }
    }

    private void proxyWindows(final String url) {
        if (!SystemUtils.IS_OS_WINDOWS) {
            LOG.info("Not running on Windows");
            return;
        }
        

        // Note we don't use toURI().toASCIIString here because the URL encoding
        // of spaces causes problems.
        //final String url = "file://"+pacFile.getAbsolutePath();
            //ACTIVE_PAC.toURI().toASCIIString().replace("file:/", "file://");
        LOG.info("Using pac path: {}", url);
        
        WIN_PROXY.setPacFile(url);
    }

    protected void unproxyWindows() {
        LOG.info("Unproxying windows");
        WIN_PROXY.unproxy();
    }
    
    private void unproxyLinux() throws ProxyConfigurationError {
        try {
            final String result1 = 
                mpm.runScript("gsettings", "set", "org.gnome.system.proxy", 
                    "mode", "'none'");
            LOG.info("Result of Ubuntu gsettings mode call: {}", result1);
        } catch (final IOException e) {
            LOG.warn("Error calling Ubuntu proxy script!", e);
            throw new ProxyConfigurationError();
        }
    }

    private void unproxyOsx() throws ProxyConfigurationError {
        // Note that this is a bit of overkill in that we both turn of the
        // PAC file-based proxying and set the PAC file to one that doesn't
        // proxy anything.
        configureOsxProxyViaScript(false, pacFileUrl(PROXY_OFF));
    }
    
    private String pacFileUrl(final File pacFile) {
        final String url = 
            "http://127.0.0.1:"+RuntimeSettings.getApiPort()+"/"+
                pacFile.getName()+"-"+RandomUtils.nextInt();
        return url;
    }

    /**
     * Calls out to AppleScript to check if the user has the security setting
     * checked to require an administrator password to unlock preferences.
     * 
     * @return <code>true</code> if the user has the setting checked, otherwise
     * <code>false</code>.
     * @throws IOException If there was a scripting error reading the 
     * preferences setting.
     */
    public boolean osxPrefPanesLocked() throws IOException {
        final String script = 
            "tell application \"System Events\"\n"+
            "    tell security preferences\n"+
            "        get require password to unlock\n"+
            "    end tell\n"+
            "end tell\n";
        final String result = 
            mpm.runScript("osascript", "-e", script);
        LOG.info("Result of script is: {}", result);

        if (StringUtils.isBlank(result)) {
            LOG.error("No result from AppleScript");
            return false;
        }
        
        // Make sure it's 
        if (LanternUtils.isTrue(result)) {
            return true;
        } else if (LanternUtils.isFalse(result)) {
            return false;
        } else {
            final String msg = "Got unexpected result from AppleScript: "+result;
            LOG.error(msg);
            throw new IOException(msg);
        }
    }

    /**
     * This will refresh the proxy entries for things like new additions to
     * the whitelist.
     */
    public void refresh() {
        if (isProxying()) {
            if (LanternHub.settings().isProxyAllSites()) {
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
}
