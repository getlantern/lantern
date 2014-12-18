package org.lantern.geoip;

import org.codehaus.jackson.annotate.JsonProperty;

public class Country {

    @JsonProperty("IsoCode")
    private String isoCode;

    public Country() {
        this.isoCode = "";
    }

    public String getIsoCode() {
        return isoCode;
    }

    public void setIsoCode(String isoCode) {
        this.isoCode = isoCode;
    }

    @Override
    public String toString() {
        return isoCode;
    }
}
