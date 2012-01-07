package org.lantern;

import java.io.File;

import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Class that does the dirty work of executing changes to the various settings 
 * users can configure.
 */
public class SettingsChangeImplementor implements MutableSystemSettings,
    MutableUserSettings {

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
        // TODO Auto-generated method stub
        
    }

    @Override
    public void setPort(final int port) {
        // Not yet supported.
    }

    @Override
    public void setCountry(final Country country) {
        if (country.equals(LanternHub.userInfo().getCountry())) {
            return;
        }
        LanternHub.userInfo().setManuallyOverrideCountry(true);
    }

    @Override
    public void setMode(final Mode mode) {
        // When we move to give mode, we want to start advertising our 
        // ID and to start accepting incoming connections.
        
        // We we move to get mode, we want to stop advertising our ID and to
        // stop accepting incoming connections.

        if (mode == LanternHub.userInfo().getMode()) {
            log.info("Mode is unchanged.");
            return;
        }
        
        // We disconnect and reconnect to create a new Jabber ID that will 
        // not advertise us as a connection point.
        LanternHub.xmppHandler().disconnect();
        LanternHub.xmppHandler().connect();
    }
}
