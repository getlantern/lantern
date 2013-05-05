package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.lantern.geoip.GeoIpLookupService;


public class DefaultCensoredTest {

    /*
    @Test
    public void testCountryOverride() throws Exception {
        LanternHub.settings().setManuallyOverrideCountry(true);
        LanternHub.settings().setCountry(new Country("CN", "China"));
        final Censored cen = LanternHub.settings().censored();
        assertTrue("Censored?", isCensored());

        LanternHub.settings().setManuallyOverrideCountry(false);
        assertFalse("Censored?", isCensored());

        assertEquals("United States",
            LanternHub.settings().getDetectedCountry().getName());
    }
    */

    @Test
    public void testExportRestricted() throws Exception {
        GeoIpLookupService geoIpLookupService = TestUtils.getGeoIpLookupService();
        final Censored cen = new DefaultCensored(geoIpLookupService);

        assertTrue(cen.isExportRestricted("78.110.96.7")); // Syria
    }

    @Test
    public void testCensored() throws Exception {

        assertTrue(isCensored("78.110.96.7")); // Syria
        assertFalse(isCensored("151.38.39.114")); // Italy
        assertFalse(isCensored("12.25.205.51")); // USA
        assertFalse(isCensored("200.21.225.82")); // Columbia
        assertTrue(isCensored("212.95.136.18")); // Iran

        assertTrue(isCensored("58.14.0.1")); // China.

        assertTrue(isCensored("190.6.64.1")); // Cuba"
        assertTrue(isCensored("58.186.0.1")); // Vietnam
        assertTrue(isCensored("82.114.160.1")); // Yemen
        //assertTrue(CensoredUtils.isCensored("196.200.96.1")); // Eritrea
        assertTrue(isCensored("213.55.64.1")); // Ethiopia
        assertTrue(isCensored("203.81.64.1")); // Myanmar
        assertTrue(isCensored("77.69.128.1")); // Bahrain
        assertTrue(isCensored("62.3.0.1")); // Saudi Arabia
        assertTrue(isCensored("62.209.128.0")); // Uzbekistan
        assertTrue(isCensored("94.102.176.1")); // Turkmenistan
        assertTrue(isCensored("175.45.176.1")); // North Korea
    }

    private boolean isCensored(String ip) {
        GeoIpLookupService lookupService = TestUtils.getGeoIpLookupService();
        GeoData location = lookupService.getGeoData(ip);
        CountryService countryService = TestUtils.getCountryService();
        Country country = countryService.getCountryByCode(location.getCountrycode());
        return country.isCensors();
    }
}
