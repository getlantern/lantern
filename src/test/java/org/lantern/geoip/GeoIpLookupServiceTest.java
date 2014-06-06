package org.lantern.geoip;

import static org.junit.Assert.*;

import java.io.IOException;
import java.io.InputStream;

import org.apache.commons.io.IOUtils;
import org.junit.Test;
import org.lantern.JsonUtils;

public class GeoIpLookupServiceTest {

    @Test
    public void testGeoIp() throws Exception {
        InputStream is = null;
        try {
            assertNotNull("Test JSON file missing", 
                getClass().getResource("/geodata.json"));
            is = getClass().getResourceAsStream("/geodata.json");
            final String geoStr = IOUtils.toString(is);
            System.out.println("GEO STR " + geoStr);
            final GeoData gd = JsonUtils.OBJECT_MAPPER.readValue(geoStr, 
                    GeoData.class);
            assertNotNull(gd);
            assertEquals(gd.getCountry().getIsoCode(), "US");
            assertNotNull(gd.getLocation());

        } catch (final IOException e) {


        } finally {
            IOUtils.closeQuietly(is);
        }
    }
}
