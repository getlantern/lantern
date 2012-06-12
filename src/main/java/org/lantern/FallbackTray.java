package org.lantern;

import java.util.Map;

import org.apache.commons.lang.SystemUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/** 
 * A SystemTray implementation that falls back among available alternatives. 
*/
class FallbackTray implements SystemTray {
    private final Logger log = LoggerFactory.getLogger(getClass());
    private SystemTray tray;
    
    public FallbackTray() {
        LanternHub.register(this);
    }

    @Override
    public void createTray() {
        if (SystemUtils.IS_OS_LINUX && LanternHub.settings().isUiEnabled() && 
            AppIndicatorTray.isSupported()) {
            tray = new AppIndicatorTray(new AppIndicatorTray.FailureCallback() {
                @Override
                public void createTrayFailed() {
                    fallback();
                }
            });
            tray.createTray(); // may call fallback() later...
        }
        else {
            fallback(); // fall back immediately
        }
    }

    @Subscribe
    public void onUpdate(final UpdateEvent update) {
        if (tray != null) {
            tray.addUpdate(update.getData());
        }
    }
    
    @Override
    public void addUpdate(final Map<String, Object> updateData) {
        tray.addUpdate(updateData);
    }

    @Override
    public boolean isActive() {
        return tray != null && tray.isActive();
    }
 
    public void fallback() {
        log.debug("App Indicator tray is not available.");
        if (LanternHub.settings().isUiEnabled() && SystemTrayImpl.isSupported()) {
            log.debug("Falling back to SWT Tray.");
            tray = new SystemTrayImpl();
            tray.createTray();
        }
        else {
            log.info("Disabling tray.");
            tray = new SystemTray() {
                @Override
                public void createTray() {}
                @Override
                public void addUpdate(Map<String, Object> updateData) {}
                @Override
                public boolean isActive() {return false;}
            };
        }
    }
}