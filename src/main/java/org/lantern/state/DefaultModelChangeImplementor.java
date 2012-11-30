package org.lantern.state;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

import javax.security.auth.login.CredentialException;

import org.apache.commons.lang.SystemUtils;
import org.lantern.DefaultXmppHandler;
import org.lantern.LanternConstants;
import org.lantern.LanternHub;
import org.lantern.LanternUtils;
import org.lantern.NotInClosedBetaException;
import org.lantern.Proxifier;
import org.lantern.state.Settings.Mode;
import org.lantern.win.Registry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.util.concurrent.ThreadFactoryBuilder;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class that does the dirty work of executing changes to the various settings 
 * users can configure.
 */
@Singleton
public class DefaultModelChangeImplementor implements ModelChangeImplementor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File launchdPlist;
    
    private final Executor proxyQueue = Executors.newSingleThreadExecutor(
        new ThreadFactoryBuilder().setDaemon(true).setNameFormat(
            "System-Proxy-Thread-%d").build());

    private final File gnomeAutostart;

    private final Model model;

    private final Proxifier proxifier;

    @Inject
    public DefaultModelChangeImplementor(final Model model,
        final Proxifier proxifier) {
        this(LanternConstants.LAUNCHD_PLIST, LanternConstants.GNOME_AUTOSTART, 
                model, proxifier);
    }
    
    public DefaultModelChangeImplementor(final File launchdPlist, 
        final File gnomeAutostart, final Model model,
        final Proxifier proxifier) {
        this.launchdPlist = launchdPlist;
        this.gnomeAutostart = gnomeAutostart;
        this.model = model;
        this.proxifier = proxifier;
    }
    
    @Override
    public void setStartAtLogin(final boolean start) {
        log.info("Setting start at login to "+start);
        if (SystemUtils.IS_OS_MAC_OSX && this.launchdPlist.isFile()) {
            setStartAtLoginOsx(start);
        } else if (SystemUtils.IS_OS_WINDOWS) {
            setStartAtLoginWindows(start);
        } else if (SystemUtils.IS_OS_LINUX) {
            log.info("Setting setStartAtLogin for Linux");
            setStartAtLoginLinux(start);
        } else {
            log.warn("setStartAtLogin not yet implemented for {}", SystemUtils.OS_NAME);
        }
    }

    public void setStartAtLoginOsx(final boolean start) {
        LanternUtils.replaceInFile(this.launchdPlist, 
                "<"+!start+"/>", "<"+start+"/>");
    }

    public void setStartAtLoginLinux(final boolean start) {
        LanternUtils.replaceInFile(this.gnomeAutostart, 
            "X-GNOME-Autostart-enabled="+!start, "X-GNOME-Autostart-enabled="+start);
    }

    public void setStartAtLoginWindows(final boolean start) {
        final String key = 
            "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
        int result = 0;
        if (start) {
            try {
                final String path = 
                    "\""+new File("Lantern.exe").getCanonicalPath()+"\"" + " --launchd";
                    //"\"\\\""+new File("Lantern.exe").getCanonicalPath()+"\\\"\"" + " --launchd";
                
                
                Registry.write(key, "Lantern", path);
            } catch (final IOException e) {
                log.error("Could not get canonical path", e);
            }
        } else {
            Registry.write(key, "Lantern", "");
        }
        
        if (result != 0) {
            log.error("Error changing startAtLogin? Result: "+result);
        }
    }
    
    @Override
    public void setProxyAllSites(final boolean proxyAll) {
    }

    @Override
    public void setSystemProxy(final boolean isSystemProxy) {
        log.info("Setting system proxy");
    }
    
    @Override
    public void setPort(final int port) {
        // Not yet supported.
        log.warn("setPort not yet implemented");
    }

    /*
    @Override
    public void setCountry(final Country country) {
        if (country.equals(LanternHub.settings().getCountry())) {
            return;
        }
        LanternHub.settings().setManuallyOverrideCountry(true);
    }
    */

    @Override
    public void setEmail(final String email) {
        final String storedEmail = LanternHub.settings().getEmail();
    }

    @Override
    public void setGetMode(final boolean getMode) {
        // When we move to give mode, we want to start advertising our 
        // ID and to start accepting incoming connections.
        
        // We we move to get mode, we want to stop advertising our ID and to
        // stop accepting incoming connections.

        final Settings set = this.model.getSettings();
        final boolean inGet = set.getMode() == Mode.get;
        if (getMode == inGet) {
            log.info("Mode is unchanged.");
            return;
        }
        if (!LanternUtils.isConfigured()) {
            log.info("Not implementing mode change -- not configured.");
            return;
        }
        
        final Mode newMode;
        if (getMode) {
            newMode = Mode.get;
        } else {
            newMode = Mode.give;
        }
        
        // Go ahead and set the setting although it will also be
        // updated by the api as well. We want to make sure the
        // state seen by the following calls is consistent with
        // this flag being aspirational vs. representational
        set.setMode(newMode);
        
        // We disconnect and reconnect to create a new Jabber ID that will 
        // not advertise us as a connection point.
        LanternConstants.INJECTOR.getInstance(DefaultXmppHandler.class).disconnect();
        try {
            try {
                LanternConstants.INJECTOR.getInstance(DefaultXmppHandler.class).connect();
                
                // TODO: This isn't quite right. We don't necessarily have
                // proxies to connect to at this point, and we shouldn't set
                // the OS proxy until we do.
                if (LanternHub.settings().isInitialSetupComplete()) {
                    // may need to modify the proxying state
                    if (LanternUtils.shouldProxy()) {
                        proxifier.startProxying();
                    } else {
                        proxifier.stopProxying();
                    }
                }
            } catch (final IOException e) {
                log.info("Could not connect to server", e);
                // Don't proxy if there's some error connecting.
                if (LanternHub.settings().isInitialSetupComplete()) {
                    proxifier.stopProxying();
                }
            } catch (final CredentialException e) {
                log.info("Credentials are wrong!!");
                if (LanternHub.settings().isInitialSetupComplete()) {
                    proxifier.stopProxying();
                }
            } catch (final NotInClosedBetaException e) {
                log.info("Not in beta!!");
                if (LanternHub.settings().isInitialSetupComplete()) {
                    proxifier.stopProxying();
                }
            }
        } catch (final Proxifier.ProxyConfigurationError e) {
            log.info("Proxy auto-configuration failed: {}", e);
        }
    }

    @Override
    public void setPassword(final String password) {
        final org.lantern.Settings set = LanternHub.settings();
    }
    
    @Override
    public void setSavePassword(final boolean savePassword) {
        log.info("Setting savePassword to {}", savePassword);
    }

    /*
    @Override
    public Model getModel() {
        return this.model;
    }
    */
}
