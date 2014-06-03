package org.lantern.geoip;

import org.codehaus.jackson.annotate.JsonAutoDetect;

@JsonAutoDetect(fieldVisibility=JsonAutoDetect.Visibility.ANY) 
public class Location {
    private double Latitude;
    private double Longitude;

    public double getLatitude() {
        return Latitude;
    }

    public void setLatitude(double Latitude) {
        this.Latitude = Latitude;
    }

    public double getLongitude() {
        return Longitude;
    }                            

    public void setLongitude(double Longitude) {
        this.Longitude = Longitude;
    }
}

