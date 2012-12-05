package org.lantern;

import java.util.Map;

import org.apache.commons.lang.SystemUtils;
import org.lantern.event.Events;
import org.lantern.event.UpdateEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;
import com.google.inject.Inject;
import com.google.inject.Singleton;

/** 
 * A SystemTray implementation that falls back among available alternatives. 
*/
@Singleton //@Named("facade")
public class FallbackTray implements SystemTray {
    private final Logger log = LoggerFactory.getLogger(getClass());
    private SystemTray nonLinuxTray;
    private AppIndicatorTray linuxTray;
    
    public FallbackTray() {
        Events.register(this);
    }

    @Inject
    public FallbackTray(final SystemTray nonLinuxTray,
        final AppIndicatorTray linuxTray) {
        this.nonLinuxTray = nonLinuxTray;
        this.linuxTray = linuxTray;
        this.linuxTray.setFailureCallback(new AppIndicatorTray.FailureCallback() {
            @Override
            public void createTrayFailed() {
                fallback();
            }
        });
    }
    

    @Override
    public void start() {
        createTray();
    }

    @Override
    public void stop() {
        
    }
    
    @Override
    public void createTray() {
        if (SystemUtils.IS_OS_LINUX && LanternHub.settings().isUiEnabled() && 
            this.linuxTray.isSupported()) {
            this.linuxTray.createTray(); // may call fallback() later...
        }
        else {
            fallback(); // fall back immediately
        }
    }

    @Subscribe
    public void onUpdate(final UpdateEvent update) {
        if (nonLinuxTray != null) {
            nonLinuxTray.addUpdate(update.getData());
        }
    }
    
    @Override
    public void addUpdate(final Map<String, Object> updateData) {
        nonLinuxTray.addUpdate(updateData);
    }

    @Override
    public boolean isActive() {
        return nonLinuxTray != null && nonLinuxTray.isActive();
    }
 
    public void fallback() {
        log.debug("App Indicator tray is not available.");
        if (LanternHub.settings().isUiEnabled() && nonLinuxTray.isSupported()) {
            log.debug("Falling back to SWT Tray.");
            nonLinuxTray.createTray();
        }
        else {
            log.info("Disabling tray.");
            nonLinuxTray = new SystemTray() {
                @Override
                public void createTray() {}
                @Override
                public void addUpdate(Map<String, Object> updateData) {}
                @Override
                public boolean isActive() {return false;}
                @Override
                public boolean isSupported() {return false;}
                @Override
                public void start() throws Exception {}
                @Override
                public void stop() {}
            };
        }
    }

    @Override
    public boolean isSupported() {
        return true;
    }
}