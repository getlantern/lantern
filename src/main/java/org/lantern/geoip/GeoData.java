package org.lantern.geoip;

import org.codehaus.jackson.annotate.JsonProperty;
 
public class GeoData {
    @JsonProperty("Country")
    private Country Country = new Country();
    @JsonProperty("Location")
    private Location Location = new Location();

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
        return "GeoData [countryCode=" + getCountry().getIsoCode() + ", latitude="
            + getLocation().getLatitude()
            + ", longitude=" + getLocation().getLongitude() + "]";
    }
}
