package org.lantern;

public class GeoData {

    private String countrycode = "";

    private double latitude = 0.0;

    private double longitude = 0.0;

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

    public String getCountrycode() {
        return countrycode;
    }

    public void setCountrycode(String countrycode) {
        this.countrycode = countrycode.toUpperCase();
    }


    @Override
    public String toString() {
        return "GeoData [countryCode=" + getCountrycode() + ", latitude=" + latitude
                + ", longitude=" + longitude + "]";
    }
}
