package org.lantern.state;

import org.apache.commons.lang3.StringUtils;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.annotation.Keep;
import org.lantern.event.Events;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;

/**
 * Location data for the client.
 */
@Keep
public class Location {

    private String country = "";

    private double lat = 0;

    private double lon = 0;

    /**
     * Whether or not we've resolved the location.
     */
    private boolean resolved = false;

    /**
     * Returns the two-letter country code for the country
     * @return
     */
    @JsonView({Run.class})
    public String getCountry() {
        return country;
    }

    public void setCountry(String country) {
        String oldCountry = this.country;
        if (country != null) {
            this.country = country.toUpperCase();
        }
        if (!StringUtils.equals(oldCountry, this.country)) {
            Events.asyncEventBus().post(
                    new LocationChangedEvent(this, oldCountry));
        }
    }

    @JsonView({Run.class, Persistent.class})
    public double getLat() {
        //return 35.6833; // Tehran
        return lat;
    }

    public void setLat(final double lat) {
        this.lat = lat;
    }

    @JsonView({Run.class, Persistent.class})
    public double getLon() {
        //return 51.4167; // Tehran
        return lon;
    }

    public void setLon(final double lon) {
        this.lon = lon;
    }

    @JsonView({Run.class})
    public boolean isResolved() {
        return resolved;
    }

    public void setResolved(boolean resolved) {
        this.resolved = resolved;
    }
}
