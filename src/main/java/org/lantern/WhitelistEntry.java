package org.lantern;

import org.lantern.annotation.Keep;

/**
 * Class representing a single whitelisted site along with any higher level
 * attributes of that site, such as whether or not it's required.
 */
@Keep
public class WhitelistEntry implements Comparable<WhitelistEntry> {

    private String site;
    private boolean defaultSetting;

    public WhitelistEntry() {
    }

    public WhitelistEntry(final String site) {
        this(site, false);
    }

    public WhitelistEntry(final String site, final boolean defaultSetting) {
        this.site = site;
        this.defaultSetting = defaultSetting;
    }

    public String getSite() {
        return site;
    }

    public void setSite(final String site) {
        this.site = site;
    }

    public void setDefault(boolean defaultSetting) {
        this.defaultSetting = defaultSetting;
    }

    public boolean isDefault() {
        return defaultSetting;
    }

    @Override
    public int compareTo(final WhitelistEntry o) {
        return this.site.compareTo(o.site);
    }

    @Override
    public String toString() {
        return this.site;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((this.site == null) ? 0 : this.site.hashCode());
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        WhitelistEntry other = (WhitelistEntry) obj;
        if (this.site == null) {
            if (other.site != null)
                return false;
        } else if (!this.site.equals(other.site))
            return false;
        return true;
    }
}
