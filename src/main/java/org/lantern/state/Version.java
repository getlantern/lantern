package org.lantern.state;

import java.util.Map;
import java.util.TreeMap;

import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.math.NumberUtils;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.LanternConstants;
import org.lantern.event.Events;
import org.lantern.event.SyncEvent;
import org.lantern.event.UpdateEvent;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;

import com.google.common.eventbus.Subscribe;

/**
 * Class containing version data for clients.
 */
public class Version {

    private final Installed installed = new Installed();
    
    private Map<String, Object> latest = new TreeMap<String, Object>();
    
    public Version() {
        Events.register(this);
    }
    
    @Subscribe
    public void onUpdate(final UpdateEvent updateEvent) {
        this.latest = updateEvent.getData();
        Events.asyncEventBus().post(new SyncEvent(SyncPath.VERSION_UPDATED, 
            updateEvent.getData()));
    }

    @JsonView({Run.class})
    public Installed getInstalled() {
        return installed;
    }

    @JsonView({Run.class, Persistent.class})
    public Map<String, Object> getLatest() {
        return latest;
    }

    public class Installed {
        private final String label = LanternConstants.VERSION;
        
        private final Api api = new Api();
        
        private final long released;
        
        public Installed() {
            if (NumberUtils.isNumber(LanternConstants.BUILD_TIME)) {
                released = Long.parseLong(LanternConstants.BUILD_TIME);
            } else {
                released = System.currentTimeMillis();
            }
        }

        @JsonView({Run.class})
        public long getReleased() {
            return released;
        }

        @JsonView({Run.class})
        public Api getApi() {
            return api;
        }
        
        @JsonView({Run.class})
        public String getLabel() {
            return label;
        }
    }

    public class Api {
        private final int major;
        
        private final int minor;
        
        private final int patch;
        
        private final boolean mock = true;
        
        public Api() {
            if ("lantern_version_tok".equals(LanternConstants.VERSION)) {
                major = 0;
                minor = 0;
                patch = 1;
            } else {
                final String[] parts = LanternConstants.VERSION.split(".");
                major = Integer.parseInt(parts[0]);
                minor = Integer.parseInt(parts[1]);
                patch = Integer.parseInt(StringUtils.substringBefore(parts[2], "-"));
            }
        }

        @JsonView({Run.class})
        public int getMajor() {
            return major;
        }

        @JsonView({Run.class})
        public int getMinor() {
            return minor;
        }

        @JsonView({Run.class})
        public int getPatch() {
            return patch;
        }

        @JsonView({Run.class})
        public boolean isMock() {
            return mock;
        }
    }
}
