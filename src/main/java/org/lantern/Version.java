package org.lantern;

import java.util.Map;
import java.util.TreeMap;

import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.math.NumberUtils;

import com.google.common.eventbus.Subscribe;

/**
 * Class containing version data for clients.
 */
public class Version {

    private final Current current = new Current();
    
    private Map<String, Object> update = new TreeMap<String, Object>();
    
    public Version() {
        LanternHub.register(this);
    }
    
    @Subscribe
    public void onUpdate(final UpdateEvent updateEvent) {
        this.update = updateEvent.getData();
        LanternHub.asyncEventBus().post(new SyncEvent(SyncChannel.version));
    }

    public Current getCurrent() {
        return current;
    }

    public Map<String, Object> getUpdate() {
        return update;
    }

    public class Current {
        private final String label = LanternConstants.VERSION;
        
        private final Api api = new Api();
        
        private final long released;
        
        public Current() {
            if (NumberUtils.isNumber(LanternConstants.BUILD_TIME)) {
                released = Long.parseLong(LanternConstants.BUILD_TIME);
            } else {
                released = System.currentTimeMillis();
            }
        }

        public long getReleased() {
            return released;
        }

        public Api getApi() {
            return api;
        }

        public String getLabel() {
            return label;
        }
    }

    public class Api {
        private final int major;
        
        private final int minor;
        
        private final int patch;
        
        private final boolean mock = false;
        
        private Api() {
            if ("lantern_version_tok".equals(LanternConstants.VERSION)) {
                major = 0;
                minor = 0;
                patch = 0;
            } else {
                final String[] parts = LanternConstants.VERSION.split(".");
                major = Integer.parseInt(parts[0]);
                minor = Integer.parseInt(parts[1]);
                patch = Integer.parseInt(StringUtils.substringBefore(parts[2], "-"));
            }
        }

        public int getMajor() {
            return major;
        }

        public int getMinor() {
            return minor;
        }

        public int getPatch() {
            return patch;
        }

        public boolean isMock() {
            return mock;
        }
    }
}
