package org.lantern;

/**
 * Class representing a single whitelisted site along with any higher level 
 *  attributes of that site, such as whether or not it's required.
 */
public class WhitelistEntry implements Comparable<WhitelistEntry> {

    private final String site;
    private final boolean required;

    public WhitelistEntry(final String site) {
        this(site, false);
    }

    public WhitelistEntry(final String site, final boolean required) {
        this.site = site;
        this.required = required;
    }

    public String getSite() {
        return site;
    }

    public boolean isRequired() {
        return required;
    }

    @Override
    public int compareTo(final WhitelistEntry o) {
        return site.compareTo(o.getSite());
    }
    
    @Override 
    public String toString() {
        return site;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + ((site == null) ? 0 : site.hashCode());
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
        if (site == null) {
            if (other.site != null)
                return false;
        } else if (!site.equals(other.site))
            return false;
        return true;
    }
}
