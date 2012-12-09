package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;


public class DefaultCensoredTest {

    /*
    @Test 
    public void testCountryOverride() throws Exception {
        LanternHub.settings().setManuallyOverrideCountry(true);
        LanternHub.settings().setCountry(new Country("CN", "China"));
        final Censored cen = LanternHub.settings().censored();
        assertTrue("Censored?", cen.isCensored());
        
        LanternHub.settings().setManuallyOverrideCountry(false);
        assertFalse("Censored?", cen.isCensored());
        
        assertEquals("United States", 
            LanternHub.settings().getDetectedCountry().getName());
    }
    */
    
    @Test 
    public void testCensored() throws Exception {
        final Censored cen = new DefaultCensored();
        final boolean censored = cen.isCensored();
        assertFalse("Censored?", censored);
        assertTrue(cen.isExportRestricted("78.110.96.7")); // Syria
        
        assertTrue(cen.isCensored("78.110.96.7")); // Syria
        assertFalse(cen.isCensored("151.38.39.114")); // Italy
        assertFalse(cen.isCensored("12.25.205.51")); // USA
        assertFalse(cen.isCensored("200.21.225.82")); // Columbia
        assertTrue(cen.isCensored("212.95.136.18")); // Iran
        
        assertTrue(cen.isCensored("58.14.0.1")); // China.
        
        assertTrue(cen.isCensored("190.6.64.1")); // Cuba" 
        assertTrue(cen.isCensored("58.186.0.1")); // Vietnam
        assertTrue(cen.isCensored("82.114.160.1")); // Yemen
        //assertTrue(CensoredUtils.isCensored("196.200.96.1")); // Eritrea
        assertTrue(cen.isCensored("213.55.64.1")); // Ethiopia
        assertTrue(cen.isCensored("203.81.64.1")); // Myanmar
        assertTrue(cen.isCensored("77.69.128.1")); // Bahrain
        assertTrue(cen.isCensored("62.3.0.1")); // Saudi Arabia
        assertTrue(cen.isCensored("62.209.128.0")); // Uzbekistan
        assertTrue(cen.isCensored("94.102.176.1")); // Turkmenistan
        assertTrue(cen.isCensored("175.45.176.1")); // North Korea
    }
}
