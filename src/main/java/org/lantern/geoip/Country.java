package org.lantern.geoip;

public class Country {

    public String IsoCode;

    public String getIsoCode() {
        return IsoCode;
    }

    public void setIsoCode(String IsoCode) {
        this.IsoCode = IsoCode;
    }

    @Override
    public String toString() {
        return IsoCode;
    }
}
