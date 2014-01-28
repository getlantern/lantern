package org.lantern.state;

import java.text.ParseException;
import java.util.Date;
import java.util.Map;
import java.util.TreeMap;

import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang3.time.DateUtils;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.DateSerializer;
import org.lantern.LanternClientConstants;
import org.lantern.LanternVersion;
import org.lantern.annotation.Keep;
import org.lantern.event.Events;
import org.lantern.event.SyncEvent;
import org.lantern.event.UpdateEvent;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * Class containing version data for clients.
 */
@Keep
public class Version {

    private static final Logger LOG = LoggerFactory.getLogger(Version.class);
    
    private final Installed installed = new Installed();

    private Map<String, Object> latest = new TreeMap<String, Object>();

    private boolean updateAvailable = false;

    public Version() {
        Events.register(this);
    }

    @Subscribe
    public void onUpdate(final UpdateEvent updateEvent) {
        latest = updateEvent.getData();
        updateAvailable = true;
        Events.asyncEventBus().post(new SyncEvent(SyncPath.VERSION_LATEST,
            latest));
        Events.sync(SyncPath.VERSION_UPDATE_AVAILABLE, true);
    }

    @JsonView({Run.class})
    public Installed getInstalled() {
        return installed;
    }

    @JsonView({Run.class, Persistent.class})
    public Map<String, Object> getLatest() {
        return latest;
    }

    public boolean isUpdateAvailable() {
        return updateAvailable;
    }

    public void setUpdateAvailable(boolean updateAvailable) {
        this.updateAvailable = updateAvailable;
    }

    @Keep
    public class Installed extends LanternVersion {

        private final String gitFull;
        private final String git;

        public Installed() {
            try {
                releaseDate = 
                    DateUtils.parseDate(LanternClientConstants.BUILD_TIME, "yyyy-MM-dd");
            } catch (final ParseException e) {
                LOG.error("Could not parse date from git plugin?", e);
                releaseDate = new Date(0); // epoch signals no releaseDate available
            }
            LOG.debug("RELEASE DATE: "+releaseDate);
            final String version = LanternClientConstants.VERSION;
            final String number = StringUtils.substringBefore(version, "-");
            final String[] parts = number.split("\\.");
            major = Integer.parseInt(parts[0]);
            minor = 0;
            patch = 0;
            if (parts.length > 1) {
                minor = Integer.parseInt(parts[1]);
                if (parts.length > 2) {
                    patch = Integer.parseInt(parts[2]);
                }
            }
            
            final String fullTag = StringUtils.substringAfter(version, "-");
            tag = StringUtils.substringBefore(fullTag, "-");

            gitFull = LanternClientConstants.GIT_VERSION;
            // the first 7 chars are sufficient to uniquely identify a revision
            //git = StringUtils.substring(gitFull, 0, 7); // XXX ends up blank?
            git = gitFull;
        }

        public String getGit() {
            return git;
        }

        @Override
        @JsonSerialize(using=DateSerializer.class)
        public Date getReleaseDate() {
            return releaseDate;
        }
    }
}
