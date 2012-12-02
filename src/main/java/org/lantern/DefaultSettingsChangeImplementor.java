package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

import javax.security.auth.login.CredentialException;

import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.SystemUtils;
import org.lantern.Proxifier.ProxyConfigurationError;
import org.lantern.state.ModelUtils;
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
public class DefaultSettingsChangeImplementor implements SettingsChangeImplementor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File launchdPlist;
    
    private final Executor proxyQueue = Executors.newSingleThreadExecutor(
        new ThreadFactoryBuilder().setDaemon(true).setNameFormat(
            "System-Proxy-Thread-%d").build());

    private final File gnomeAutostart;

    private final XmppHandler xmppHandler;

    private final Proxifier proxifier;

    private final ModelUtils modelUtils;

    @Inject
    public DefaultSettingsChangeImplementor(final XmppHandler xmppHandler,
        final Proxifier proxifier, final ModelUtils modelUtils) {
        this(LanternConstants.LAUNCHD_PLIST, LanternConstants.GNOME_AUTOSTART,
                xmppHandler, proxifier, modelUtils);
    }
    
    public DefaultSettingsChangeImplementor(final File launchdPlist, 
        final File gnomeAutostart, final XmppHandler xmppHandler,
        final Proxifier proxifier, final ModelUtils modelUtils) {
        this.launchdPlist = launchdPlist;
        this.gnomeAutostart = gnomeAutostart;
        this.xmppHandler = xmppHandler;
        this.proxifier = proxifier;
        this.modelUtils = modelUtils;
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
        try {
            proxifier.proxyAllSites(proxyAll);
        } catch (final ProxyConfigurationError e) {
            throw new RuntimeException("Error proxying all sites!", e);
        }
    }

    @Override
    public void setSystemProxy(final boolean isSystemProxy) {
        if (isSystemProxy == LanternHub.settings().isSystemProxy()) {
            log.info("System proxy setting is unchanged.");
            return;
        }
        
        log.info("Setting system proxy");
        
        // go ahead and change the setting so that it will affect
        // shouldProxy. it will be set again by the api, but that
        // doesn't matter.
        LanternHub.settings().setSystemProxy(isSystemProxy);
        if (!LanternHub.settings().isInitialSetupComplete()) {
            return;
        }
        
        final Runnable proxyRunner = new Runnable() {
            @Override
            public void run() {
                try {
                    if (LanternUtils.shouldProxy() ) {
                        proxifier.startProxying();
                    } else {
                        proxifier.stopProxying();
                    }
                } catch (final Proxifier.ProxyConfigurationError e) {
                    log.error("Proxy reconfiguration failed: {}", e);
                }
            }
        };
        proxyQueue.execute(proxyRunner);
    }
    
    @Override
    public void setPort(final int port) {
        // Not yet supported.
        log.warn("setPort not yet implemented");
    }

    @Override
    public void setCountry(final Country country) {
        if (country.equals(LanternHub.settings().getCountry())) {
            return;
        }
        LanternHub.settings().setManuallyOverrideCountry(true);
    }

    @Override
    public void setEmail(final String email) {
        final String storedEmail = LanternHub.settings().getEmail();
        if ((email == null && storedEmail == null)) {
            log.info("Email is unchanged.");
            return;
        }
        if (storedEmail != null && storedEmail.equals(email)) {
            log.info("Email is unchanged.");
            return;
        }
        log.info("Email address changed. Clearing user specific settings");
        LanternHub.resetUserConfig();
    }

    @Override
    public void setGetMode(final boolean getMode) {
        // When we move to give mode, we want to start advertising our 
        // ID and to start accepting incoming connections.
        
        // We we move to get mode, we want to stop advertising our ID and to
        // stop accepting incoming connections.

        if (getMode == LanternHub.settings().isGetMode()) {
            log.info("Mode is unchanged.");
            return;
        }
        if (!modelUtils.isConfigured()) {
            log.info("Not implementing mode change -- not configured.");
            return;
        }
        
        // Go ahead and set the setting although it will also be
        // updated by the api as well. We want to make sure the
        // state seen by the following calls is consistent with
        // this flag being aspirational vs. representational
        LanternHub.settings().setGetMode(getMode);
        
        // We disconnect and reconnect to create a new Jabber ID that will 
        // not advertise us as a connection point.
        xmppHandler.disconnect();
        try {
            try {
                xmppHandler.connect();
                
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
        final Settings set = LanternHub.settings();
        if (StringUtils.isBlank(password)) {
            log.info("Clearing password");
            set.setStoredPassword("");
            set.setPasswordSaved(false);
        } else {
            log.info("Setting password");
            if (set.isSavePassword()) {
                set.setStoredPassword(password);
                set.setPasswordSaved(true);
            } else {
                set.setStoredPassword("");
                set.setPasswordSaved(false);
            }
        }
    }
    
    @Override
    public void setSavePassword(final boolean savePassword) {
        log.info("Setting savePassword to {}", savePassword);
        final Settings set = LanternHub.settings();
        if (savePassword) {
            final String password = set.getPassword();
            if (password != null && !password.equals("")) {
                log.info("Restoring from current password");
                set.setStoredPassword(password);
                set.setPasswordSaved(true);
            }
        }
        else {
            log.info("Clearing existing stored password (if any)");
            set.setStoredPassword("");
            set.setPasswordSaved(false);
        }
    }
    
}
