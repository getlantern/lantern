package org.lantern.geoip;

public class Location {
    public double Latitude;
    public double Longitude;

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

