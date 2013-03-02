package org.lantern.state;

public class LocationChangedEvent {

    private final Location newLocation;
    private final String oldCountry;

    public LocationChangedEvent(Location newLocation, String oldCountry) {
        this.oldCountry = oldCountry;
        this.newLocation = newLocation;
    }

    public String getOldCountry() {
        return oldCountry;
    }

    public String getNewCountry() {
        return newLocation.getCountry();
    }

    public Location getNewLocation() {
        return newLocation;
    }

}
