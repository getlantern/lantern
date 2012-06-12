package org.lantern;

import java.util.Map;

import org.lantern.linux.AppIndicator; 
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.apache.commons.lang.SystemUtils;

/*
A SystemTray implementation that falls back 
among available alternatives. 
*/
class FallbackTray implements SystemTray {
    private final Logger log = LoggerFactory.getLogger(getClass());
	private SystemTray _tray = null;

	public FallbackTray() {
		super();
	}

	@Override
	public void createTray() {
		if (SystemUtils.IS_OS_LINUX && LanternHub.settings().isUiEnabled() && AppIndicatorTray.isSupported()) {
			_tray = new AppIndicatorTray(new AppIndicatorTray.FailureCallback() {
				public void createTrayFailed() {
					fallback();
				}
			});
			_tray.createTray(); // may call fallback() later...
		}
		else {
			fallback(); // fall back immediately
		}
	}

	@Override
    public void addUpdate(Map<String, String> updateData) {
    	_tray.addUpdate(updateData);
    }

    @Override
    public boolean isActive() {
    	return _tray != null && _tray.isActive();
    }
 
    public void fallback() {
    	log.debug("App Indicator tray is not available.");
    	if (LanternHub.settings().isUiEnabled() && SystemTrayImpl.isSupported()) {
    		log.debug("Falling back to SWT Tray.");
    		_tray = new SystemTrayImpl();
    		_tray.createTray();
    	}
    	else {
    		log.info("Disabling tray.");
    		_tray = new SystemTray() {
	            @Override
	            public void createTray() {}
	            @Override
	            public void addUpdate(Map<String, String> updateData) {}
	            @Override
	            public boolean isActive() {return false;}
            };
    	}
    }
}