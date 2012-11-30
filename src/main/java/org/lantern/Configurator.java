package org.lantern;

import java.io.File;
import java.io.IOException;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.SystemUtils;
import org.eclipse.swt.SWT;
import org.lantern.event.ConnectivityStatusChangeEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Configures Lantern. This can be either on the first run of the application
 * or through the user changing his or her configurations in the configuration
 * screen.
 */
@Singleton
public class Configurator {
    
    private final Logger LOG = 
        LoggerFactory.getLogger(Configurator.class);
    
    private volatile boolean configured = false;

    private final Proxifier proxifier;

    private final MessageService messageService;
    
    /**
     * Creates a new configurator.
     */
    @Inject
    public Configurator(final Proxifier proxifier, 
        final MessageService messageService) {
        this.proxifier = proxifier;
        this.messageService = messageService;
        Events.register(this);
    }
    
    @Subscribe
    public void onConnectivityEvent(final ConnectivityStatusChangeEvent event) {
        final ConnectivityStatus status = event.getConnectivityStatus();
        switch (status) {
        case CONNECTED:
            // Note that this call won't do anything on the first run if the
            // setup screens have not completed -- proxy configuration in
            // that case happens as a result of the setup complete API call.
            // This call is necessary in subsequent cases, however, when the
            // user has completed the setup screens, and Lantern simply 
            // needs to start up in the correct proxy state.
            configure();
            break;
        case CONNECTING:
            break;
        case DISCONNECTED:
            break;
        }
    }
    
    public void configure() {
        
        LOG.info("Configuring...");
        if (configured) {
            LOG.info("Configure called multiple times?");
            return;
        }
        configured = true;
        reconfigure();
    }
    

    /**
     * Copies our FireFox extension to the appropriate place.
     * 
     * @return The {@link File} for the final destination directory of the
     * extension.
     * @throws IOException If there's an error copying the extension.
     */
    public void copyFireFoxExtension() throws IOException {
        LOG.info("Copying FireFox extension");
        final File dir = getExtensionDir();
        if (!dir.isDirectory()) {
            LOG.info("Making FireFox extension directory...");
            // NOTE: This likely means the user does not have FireFox. We copy
            // the extension here anyway in case the user ever installs 
            // FireFox in the future.
            if (!dir.mkdirs()) {
                LOG.error("Could not create ext dir: "+dir);
                throw new IOException("Could not create ext dir: "+dir);
            }
        }
        final String extName = "lantern@getlantern.org";
        final File dest = new File(dir, extName);
        final File ffDir = new File("firefox/"+extName);
        if (dest.exists() && !FileUtils.isFileNewer(ffDir, dest)) {
            LOG.info("Extension already exists and ours is not newer");
            return;
        }
        if (!ffDir.isDirectory()) {
            LOG.error("No extension directory found at {}", ffDir);
            throw new IOException("Could not find extension?");
        }
        FileUtils.copyDirectoryToDirectory(ffDir, dir);
        LOG.info("Copied FireFox extension from {} to {}", ffDir, dir);
    }

    public File getExtensionDir() {
        final File userHome = SystemUtils.getUserHome();
        if (SystemUtils.IS_OS_WINDOWS) {
            final File ffDir = new File(System.getenv("APPDATA"), "Mozilla");
            return new File(ffDir, "Extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            return new File(userHome, 
                "Library/Application Support/Mozilla/Extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        } else {
            return new File(userHome, "Mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}");
        }
    }

    public void reconfigure() {
        if (!LanternUtils.isConfigured()) {
            System.out.println("GOOGLE ACCOUNT NOT CONFIGURED");
            return;
        }
        final File git = new File(".git");
        if (git.isDirectory() && !LanternHub.settings().isGetMode()) {
            LOG.info("Running from repository...not auto-configuring proxy.");
            return;
        }
        
        if (LanternUtils.shouldProxy() &&
            (!LanternHub.settings().isUiEnabled() || LanternHub.settings().isInitialSetupComplete())) {
            LOG.info("Auto-configuring proxy...");
            boolean finished = false;
            while (!finished) {
                try {
                    proxifier.startProxying();
                    finished = true;
                } catch (Proxifier.ProxyConfigurationError e) {
                    if (LanternHub.settings().isUiEnabled()) {
                         // XXX I18n / copy 
                         final String question = "Failed to set Lantern as the system proxy.\n\n" +
                            "If you cancel, Lantern will not be used to handle " +
                            "your web traffic unless you manually configure your proxy settings.\n\n" +
                            "Try again?";
                        final int response = 
                            messageService.askQuestion("Proxy Settings", question,
                                SWT.APPLICATION_MODAL | SWT.ICON_INFORMATION | SWT.RETRY | SWT.CANCEL);
                        if (response == SWT.CANCEL) {
                            finished = true;
                        }
                    }
                    else {
                        LOG.error("Failed to set lantern as the system proxy: {}", e);
                        finished = true;
                    }
                }
            }
        } else {
            LOG.info("Not auto-configuring proxy.");
        }
    }
    
    public boolean configured() {
        return configured;
    }

    /**
     * Installs the FireFox config file on startup. 
     */
    private void copyFirefoxConfig() {
        final File ff;
        if (SystemUtils.IS_OS_WINDOWS) {
            ff = new File(System.getenv("ProgramFiles"), "Mozilla Firefox");
        } else if (SystemUtils.IS_OS_MAC_OSX) {
            ff = new File("/Applications/Firefox.app//Contents/MacOS");
        } else {
            LOG.info("Not sure where to copy FireFox config on Linux");
            return;
        }
        final File pref = new File(new File(ff, "defaults"), "pref");
        LOG.info("Prefs dir: {}", pref);
        if (ff.isDirectory() && !pref.isDirectory()) {
            LOG.error("No directory at: {}", pref);
        }
        final File config = new File("all-lantern.js");
        
        if (!config.isFile()) {
            LOG.error("NO CONFIG FILE AT {}", config);
        }
        else {
            try {
                FileUtils.copyFileToDirectory(config, pref);
                final File installedConfig = new File(pref, config.getName());
                installedConfig.deleteOnExit();
            } catch (final IOException e) {
                LOG.error("Could not copy config file?", e);
            }
        }
    }

    
    /*
     * This is done in the installer.
    private void configureWindowsFirewall() {
        final boolean oldNetSh;
        if (SystemUtils.IS_OS_WINDOWS_2000 ||
            SystemUtils.IS_OS_WINDOWS_XP) {
            oldNetSh = true;
        }
        else {
            oldNetSh = false;
        }

        if (oldNetSh) {
            final String[] commands = {
                "netsh", "firewall", "add", "allowedprogram", 
                "\""+SystemUtils.getUserDir()+"/Lantern.exe\"", "\"Lantern\"", 
                "ENABLE"
            };
            CommonUtils.nativeCall(commands);
        } else {
            final String[] commands = {
                "netsh", "advfirewall", "firewall", "add", "rule", 
                "name=\"Lantern\"", "dir=in", "action=allow", 
                "program=\""+SystemUtils.getUserDir()+"/Lantern.exe\"", 
                "enable=yes", "profile=any"
            };
            CommonUtils.nativeCall(commands);
        }
    }
    */
}
