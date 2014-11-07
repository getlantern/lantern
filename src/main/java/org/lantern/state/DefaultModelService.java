package org.lantern.state;

import java.io.File;
import java.io.IOException;
import java.util.List;

import org.apache.commons.lang.SystemUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.Proxifier.ProxyConfigurationError;
import org.lantern.ProxyService;
import org.lantern.event.AutoReportChangedEvent;
import org.lantern.event.Events;
import org.lantern.event.ModeChangedEvent;
import org.lantern.event.SyncEvent;
import org.lantern.win.Registry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * Class that does the dirty work of executing changes to the various settings
 * users can configure.
 */
@Singleton
public class DefaultModelService implements ModelService {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final File launchdPlist;

    private final File gnomeAutostart;

    private final Model model;

    private final ProxyService proxifier;

    @Inject
    public DefaultModelService(final Model model,
        final ProxyService proxifier) {
        this(LanternClientConstants.LAUNCHD_PLIST, 
            LanternClientConstants.GNOME_AUTOSTART,model, proxifier);
    }

    public DefaultModelService(final File launchdPlist,
        final File gnomeAutostart, final Model model,
        final ProxyService proxifier) {
        this.launchdPlist = launchdPlist;
        this.gnomeAutostart = gnomeAutostart;
        this.model = model;
        this.proxifier = proxifier;
    }

    @Override
    public void setRunAtSystemStart(final boolean runOnSystemStartup) {
        log.debug("Setting start at login to "+runOnSystemStartup);

        this.model.getSettings().setRunAtSystemStart(runOnSystemStartup);
        Events.sync(SyncPath.START_AT_LOGIN, runOnSystemStartup);
        if (SystemUtils.IS_OS_MAC_OSX && this.launchdPlist.isFile()) {
            setStartAtLoginOsx(runOnSystemStartup);
        } else if (SystemUtils.IS_OS_WINDOWS) {
            setStartAtLoginWindows(runOnSystemStartup);
        } else if (SystemUtils.IS_OS_LINUX) {
            log.info("Setting setStartAtLogin for Linux");
            setStartAtLoginLinux(runOnSystemStartup);
        } else {
            log.warn("setStartAtLogin not yet implemented for {}", 
                SystemUtils.OS_NAME);
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
    public void resetProxiedSites() {
        Settings settings = model.getSettings();
        settings.getWhitelist().reset();
        proxifier.refresh();
    }

    @Override
    public void setProxiedSites(List<String> proxiedSites) {
        model.getSettings().setProxiedSites(proxiedSites.toArray(new String[0]));
        proxifier.refresh();
    }
    
    @Override
    public void setProxyAllSites(final boolean proxyAll) {
        this.model.getSettings().setProxyAllSites(proxyAll);
        Events.sync(SyncPath.PROXY_ALL_SITES, proxyAll);
        try {
            proxifier.proxyAllSites(proxyAll);
        } catch (final ProxyConfigurationError e) {
            throw new RuntimeException("Error proxying all sites!", e);
        }
    }

    @Override
    public void setSystemProxy(final boolean isSystemProxy) {
        log.debug("Set system proxy called");
        if (isSystemProxy == this.model.getSettings().isSystemProxy()) {
            log.info("System proxy setting is unchanged.");
            return;
        }
        log.info("Setting system proxy");
        this.model.getSettings().setSystemProxy(isSystemProxy);
    }

    @Override
    public Mode getMode() {
        return model.getSettings().getMode();
    }

    @Override
    public void setMode(final Mode mode) {
        log.debug("Calling set mode. Mode is: {}", mode);
        // One thing we want to do when we switch to 
        final Settings set = this.model.getSettings();
        
        // We rely on this to determine whether or not the user needs to
        // do more configuration when switching modes.
        if (mode == Mode.get) {
            model.setEverGetMode(true);
        }
        if (set.getMode() != mode) {
            log.debug("Propagating events for mode change...");
            set.setMode(mode);
            Events.eventBus().post(new SyncEvent(SyncPath.MODE, mode));
            Events.asyncEventBus().post(new ModeChangedEvent(mode));
        }
    }

    @Override
    public void setAutoReport(final boolean autoReport) {
        Settings settings = this.model.getSettings();
        boolean wasAutoReport = settings.isAutoReport();
        settings.setAutoReport(autoReport);
        Events.sync(SyncPath.AUTO_REPORT, autoReport);
        if (autoReport != wasAutoReport) {
            Events.asyncEventBus().post(new AutoReportChangedEvent(autoReport));
        }
    }

    @Override
    public void setShowFriendPrompts(final boolean showFriendPrompts) {
        this.model.getSettings().setShowFriendPrompts(showFriendPrompts);
        Events.sync(SyncPath.SHOW_FRIEND_PROMPTS, showFriendPrompts);
    }

    //this is necessary for JSON-pointer updating, since we want
    //all updates to go through this class
    public DefaultModelService getSettings() {
        return this;
    }

    /*
    @Override
    public void setAutoConnect(boolean autoConnect) {
        this.model.getSettings().setAutoConnect(autoConnect);
        Events.sync(SyncPath.AUTO_CONNECT, autoConnect);
    }
    */
}
