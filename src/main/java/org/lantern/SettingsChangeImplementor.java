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
        LanternHub.userInfo().setManualCountry(true);
    }

    @Override
    public void setConnectOnLaunch(final boolean connectOnLaunch) {
        
    }
}
