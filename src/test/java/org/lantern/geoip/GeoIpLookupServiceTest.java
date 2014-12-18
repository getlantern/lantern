package org.lantern.geoip;

import org.junit.Test;

/**
 * Test for the lookup service.
 */
public class GeoIpLookupServiceTest {

    @Test
    public void test() throws Exception {
        final GeoIpLookupService service = new GeoIpLookupService();
        
        // Just make sure we can correctly parse the response from a Chinese
        // IP address that should include UTF-8 characters.
        service.getGeoData("58.14.0.1");
    }

}
