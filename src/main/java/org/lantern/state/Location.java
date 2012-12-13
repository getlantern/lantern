package org.lantern.state;

import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.state.Model.Run;

/**
 * Location data for the client.
 */
public class Location {

    private String country = "gb";

    private int lat = 54;
    
    private int lon = -2;

    @JsonView({Run.class})
    public String getCountry() {
        return country;
    }

    public void setCountry(final String country) {
        if (country != null) {
            this.country = country.toLowerCase();
        }
    }
    
    @JsonView({Run.class})
    public int getLat() {
        return lat;
    }

    public void setLat(int lat) {
        this.lat = lat;
    }

    @JsonView({Run.class})
    public int getLon() {
        return lon;
    }

    public void setLon(int lon) {
        this.lon = lon;
    }
}
