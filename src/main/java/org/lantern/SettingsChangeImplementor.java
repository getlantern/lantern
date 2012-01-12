package org.lantern;

import java.io.File;
import java.io.IOException;

import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class that does the dirty work of executing changes to the various settings 
 * users can configure.
 */
public class SettingsChangeImplementor implements MutableSettings {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File launchdPlist;

    public SettingsChangeImplementor() {
        this(LanternConstants.LAUNCHD_PLIST);
    }
    
    public SettingsChangeImplementor(final File launchdPlist) {
        this.launchdPlist = launchdPlist;
    }
    
    @Override
    public void setStartAtLogin(final boolean start) {
        if (SystemUtils.IS_OS_MAC_OSX && this.launchdPlist.isFile()) {
            log.info("Setting start at login to "+start);
            LanternUtils.replaceInFile(this.launchdPlist, 
                "<"+!start+"/>", "<"+start+"/>");
        } else if (SystemUtils.IS_OS_WINDOWS) {
            // TODO: Make this work on Windows and Linux!! Tricky on Windows
            // because it's not clear we have permissions to modify the
            // registry in all cases.
        }
    }

    @Override
    public void setSystemProxy(final boolean isSystemProxy) {
        log.info("Setting system proxy");
        if (isSystemProxy) {
            Configurator.startProxying();
        } else {
            Configurator.stopProxying();
        }
    }

    @Override
    public void setPort(final int port) {
        // Not yet supported.
    }

    @Override
    public void setCountry(final Country country) {
        if (country.equals(LanternHub.settings().getCountry())) {
            return;
        }
        LanternHub.settings().setManuallyOverrideCountry(true);
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
        
        // We disconnect and reconnect to create a new Jabber ID that will 
        // not advertise us as a connection point.
        LanternHub.xmppHandler().disconnect();
        try {
            LanternHub.xmppHandler().connect();
        } catch (final IOException e) {
            log.info("Could not login", e);
        }
    }

    @Override
    public void setSavePassword(final boolean savePassword) {
        final Settings set = LanternHub.settings();
        if (!savePassword) {
            set.setStoredPassword("");
        } else {
            set.setStoredPassword(set.getPassword());
        }
    }
}
