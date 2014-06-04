package org.lantern.geoip;

import org.codehaus.jackson.annotate.JsonProperty;

public class Location {
    @JsonProperty("Latitude")
    private double latitude;
    @JsonProperty("Longitude")
    private double longitude;

    public Location() {
        this.latitude  = 0.0;
        this.longitude = 0.0;
    }

    public double getLatitude() {
        return latitude;
    }

    public void setLatitude(double latitude) {
        this.latitude = latitude;
    }

    public double getLongitude() {
        return longitude;
    }                            

    public void setLongitude(double longitude) {
        this.longitude = longitude;
    }
}

