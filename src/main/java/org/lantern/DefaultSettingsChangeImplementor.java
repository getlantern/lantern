package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class that does the dirty work of executing changes to the various settings 
 * users can configure.
 */
public class DefaultSettingsChangeImplementor implements SettingsChangeImplementor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File launchdPlist;
    
    private final Executor proxyQueue = 
        Executors.newSingleThreadExecutor(new ThreadFactory() {
            @Override
            public Thread newThread(final Runnable r) {
                final Thread t = new Thread(r, "System-Proxy-Thread");
                t.setDaemon(true);
                return t;
            }
        });

    public DefaultSettingsChangeImplementor() {
        this(LanternConstants.LAUNCHD_PLIST);
    }
    
    public DefaultSettingsChangeImplementor(final File launchdPlist) {
        this.launchdPlist = launchdPlist;
    }
    
    @Override
    public void setStartAtLogin(final boolean start) {
        if (SystemUtils.IS_OS_MAC_OSX && this.launchdPlist.isFile()) {
            log.info("Setting start at login to "+start);
            LanternUtils.replaceInFile(this.launchdPlist, 
                "<"+!start+"/>", "<"+start+"/>");
        } else if (SystemUtils.IS_OS_WINDOWS) {
            final String key = 
                "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run";
            int result = 0;
            if (start) {
                try {
                    final String path = 
                        "\"\\\""+new File("lantern.exe").getCanonicalPath()+"\\\"\"";
                    result = WindowsRegistry.writeREG_SZ(key, "Lantern", path);
                } catch (final IOException e) {
                    log.error("Could not get canonical path", e);
                }
            } else {
                result = WindowsRegistry.writeREG_SZ(key, "Lantern", "");
            }
            
            if (result != 0) {
                log.error("Error enabling proxy server? Result: "+result);
            }
        } else if (SystemUtils.IS_OS_LINUX) {
            // TODO: Make this work on Linux!! 
            log.warn("setStartAtLogin not yet implemented for Linux");
        } else {
            log.warn("setStartAtLogin not yet implemented for {}", SystemUtils.OS_NAME);
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
                        Proxifier.startProxying();
                    } else {
                        Proxifier.stopProxying();
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
        if (!LanternUtils.isConfigured()) {
            log.info("Not implementing mode change -- not configured.");
            return;
        }
        
        // Go ahead and set the setting although it will also be
        // updated by the api as well.  We want to make sure the
        // state seen by the following calls is consistent with
        // this flag being aspirational vs. representational
        LanternHub.settings().setGetMode(getMode);
        
        // We disconnect and reconnect to create a new Jabber ID that will 
        // not advertise us as a connection point.
        LanternHub.xmppHandler().disconnect();
        try {
            try {
                LanternHub.xmppHandler().connect();
                
                // TODO: This isn't quite right. We don't necessarily have
                // proxies to connect to at this point, and we shouldn't set
                // the OS proxy until we do.
                if (LanternHub.settings().isInitialSetupComplete()) {
                    // may need to modify the proxying state
                    if (LanternUtils.shouldProxy()) {
                        Proxifier.startProxying();
                    } else {
                        Proxifier.stopProxying();
                    }
                }
            } catch (final IOException e) {
                log.info("Could not login", e);
                // Don't proxy if there's some error connecting.
                if (LanternHub.settings().isInitialSetupComplete()) {
                    Proxifier.stopProxying();
                }
            }
        } catch (final Proxifier.ProxyConfigurationError e) {
            log.info("Proxy auto-configuration failed: {}", e);
        }
    }

    @Override
    public void setPassword(final String password) {
        log.info("Setting password");
        final Settings set = LanternHub.settings();
        if (set.isSavePassword()) {
            set.setStoredPassword(password);
            set.setPasswordSaved(true);
        } else {
            set.setStoredPassword("");
            set.setPasswordSaved(false);
        }
    }
    
    @Override
    public void setSavePassword(final boolean savePassword) {
        log.info("Setting savePassword to {}", savePassword);
        final Settings set = LanternHub.settings();
        set.setSavePassword(savePassword);
        if (!savePassword) {
            log.info("Clearing existing stored password (if any)");
            this.setPassword("");
        }
    }
    
}
