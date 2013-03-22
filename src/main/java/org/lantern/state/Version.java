package org.lantern.state;

import java.util.Date;
import java.util.Map;
import java.util.TreeMap;

import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.math.NumberUtils;
import org.codehaus.jackson.map.annotate.JsonSerialize;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.LanternClientConstants;
import org.lantern.LanternConstants;
import org.lantern.VersionNumber;
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

    private boolean updateAvailable = false;

    public Version() {
        Events.register(this);
    }

    @Subscribe
    public void onUpdate(final UpdateEvent updateEvent) {
        latest = updateEvent.getData();
        String versionStr = (String) latest.get(LanternConstants.UPDATE_VERSION_KEY);
        VersionNumber newVersion = new VersionNumber(versionStr);
        if (installed.getMajor() < newVersion.getMajor()) {
            setUpdateAvailable(true);
        } else if (installed.getMajor() == newVersion.getMajor()) {
            if (installed.getMinor() < newVersion.getMinor()) {
                setUpdateAvailable(true);
            }
        }
        Events.asyncEventBus().post(new SyncEvent(SyncPath.VERSION,
            this));
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

    public class Installed {

        private final int major;

        private final int minor;

        private final int patch;

        private final String tag = "";

        private final String git;

        private final SemanticVersion api = new SemanticVersion(0, 0, 1);

        private final SemanticVersion modelSchema = new SemanticVersion(0, 0, 1);

        private final Date releaseDate;

        private String installerUrl;

        private String installerSHA1;

        public Installed() {
            if (NumberUtils.isNumber(LanternConstants.BUILD_TIME)) {
                releaseDate = new Date(Long.parseLong(LanternConstants.BUILD_TIME));
            } else {
                releaseDate = new Date(System.currentTimeMillis());
            }
            if ("lantern_version_tok".equals(LanternClientConstants.VERSION)) {
                major = 0;
                minor = 21;
                patch = 0;
                git = "";
            } else {
                final String[] parts = LanternClientConstants.VERSION.split("\\.");
                major = Integer.parseInt(parts[0]);
                minor = Integer.parseInt(parts[1]);
                patch = Integer.parseInt(StringUtils.substringBefore(parts[2], "-"));
                git = StringUtils.substringAfter(parts[2], "-");
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

        public String getTag() {
            return tag;
        }

        public String getGit() {
            return git;
        }

        @JsonView({Run.class})
        public SemanticVersion getApi() {
            return api;
        }

        @JsonSerialize(using=DateSerializer.class)
        public Date getReleaseDate() {
            return releaseDate;
        }

        public SemanticVersion getModelSchema() {
            return modelSchema;
        }

        public String getInstallerUrl() {
            return installerUrl;
        }


        public void setInstallerUrl(String installerUrl) {
            this.installerUrl = installerUrl;
        }


        public String getInstallerSHA1() {
            return installerSHA1;
        }


        public void setInstallerSHA1(String installerSHA1) {
            this.installerSHA1 = installerSHA1;
        }

    }

    public class SemanticVersion {
        private final int major;

        private final int minor;

        private final int patch;

        private final boolean mock = true;

        public SemanticVersion(final int major, final int minor, final int patch) {
            this.major = major;
            this.minor = minor;
            this.patch = patch;
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
