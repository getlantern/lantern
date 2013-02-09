package org.lantern.state;

import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.state.Model.Persistent;
import org.lantern.state.Model.Run;

/**
 * Location data for the client.
 */
public class Location {

    private String country = "";

    private double lat = 0;

    private double lon = 0;

    @JsonView({Run.class})
    public String getCountry() {
        return country;
    }

    public void setCountry(final String country) {
        if (country != null) {
            this.country = country.toUpperCase();
        }
    }

    @JsonView({Run.class, Persistent.class})
    public double getLat() {
        return lat;
    }

    public void setLat(final double lat) {
        this.lat = lat;
    }

    @JsonView({Run.class, Persistent.class})
    public double getLon() {
        return lon;
    }

    public void setLon(final double lon) {
        this.lon = lon;
    }
}
