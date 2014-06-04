package org.lantern.geoip;
 
public class GeoData {
    public Country Country;
    public Location Location;

    public void setLocation(Location Location) {
        this.Location = Location;
    }

    public Location getLocation() {
        return Location;
    }

    public void setCountry(Country Country) {
        this.Country = Country;
    }

    public Country getCountry() {
        return Country;
    }

    @Override
    public String toString() {
        System.out.println("----> " + getLocation().getLatitude());
        return "GeoData [countryCode=" + getCountry().getIsoCode() + ", latitude="
            + getLocation().getLatitude()
            + ", longitude=" + getLocation().getLongitude() + "]";
    }
}
