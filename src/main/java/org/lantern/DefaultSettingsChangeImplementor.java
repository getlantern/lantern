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
public class DefaultSettingsChangeImplementor implements SettingsChangeImplementor {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final File launchdPlist;

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
            // TODO: Make this work on Windows and Linux!! Tricky on Windows
            // because it's not clear we have permissions to modify the
            // registry in all cases.
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
        
        if (LanternUtils.shouldProxy()) {
            Proxifier.startProxying();
        } else {
            Proxifier.stopProxying();
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
            LanternHub.xmppHandler().connect();
        } catch (final IOException e) {
            log.info("Could not login", e);
        }

        // may need to modify the proxying state
        if (LanternUtils.shouldProxy()) {
            Proxifier.startProxying();
        } else {
            Proxifier.stopProxying();
        }
    }

    @Override
    public void setSavePassword(final boolean savePassword) {
        final Settings set = LanternHub.settings();
        if (!savePassword) {
            set.setStoredPassword("");
            set.setPasswordSaved(false);
        } else {
            set.setStoredPassword(set.getPassword());
            set.setPasswordSaved(true);
        }
    }

    @Override
    public void setPassword(final String password) {
        final Settings set = LanternHub.settings();
        if (set.isSavePassword()) {
            set.setStoredPassword(password);
            set.setPasswordSaved(true);
        } 
    }
    
}
