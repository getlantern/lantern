package org.lantern.geoip;
 
import org.codehaus.jackson.annotate.JsonAutoDetect;

@JsonAutoDetect(fieldVisibility=JsonAutoDetect.Visibility.ANY) 
public class Country {
    private String IsoCode;

    public String getIsoCode() {
        return IsoCode;
    }

    public void setIsoCode(String IsoCode) {
        this.IsoCode = IsoCode;
    }
}
