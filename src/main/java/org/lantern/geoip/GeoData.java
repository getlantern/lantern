package org.lantern.geoip;

import org.codehaus.jackson.annotate.JsonAutoDetect;

@JsonAutoDetect(fieldVisibility=JsonAutoDetect.Visibility.ANY)
public class GeoData {
    private Country Country;
    private Location Location;

    public Location getLocation() {
        return Location;
    }

    public void setLocation(Location location) {
        this.Location = location;
    }

    public Country getCountry() {
        return Country;
    }           

    public void setCountry(Country country) {
        this.Country = country;
    }

    @Override
    public String toString() {
        return "GeoData [countryCode=" + getCountry().getIsoCode() + ", latitude="
            + getLocation().getLatitude()
            + ", longitude=" + getLocation().getLongitude() + "]";
    }
}
