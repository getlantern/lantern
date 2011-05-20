package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.net.InetSocketAddress;
import java.util.HashSet;
import java.util.Set;

import org.junit.Test;

/**
 * Test for Lantern utilities.
 */
public class LanternUtilsTest {
    
    @Test public void inetSocketTest() throws Exception {
        final Set<InetSocketAddress> set = new HashSet<InetSocketAddress>();
        final InetSocketAddress isa1 = 
            new InetSocketAddress("racheljohnsonftw.appspot.com", 443);
        set.add(isa1);
        
        final InetSocketAddress isa2 = 
            new InetSocketAddress("racheljohnsonla.appspot.com", 443);
        
        set.add(isa2);
        assertEquals(2, set.size());
    }

    @Test public void testCensored() throws Exception {
        final boolean censored = LanternUtils.isCensored();
        assertFalse("Censored?", censored);
        assertTrue(LanternUtils.isExportRestricted("78.110.96.7")); // Syria
        
        
        assertTrue(LanternUtils.isCensored("78.110.96.7")); // Syria
        assertFalse(LanternUtils.isCensored("151.38.39.114")); // Italy
        assertFalse(LanternUtils.isCensored("12.25.205.51")); // USA
        assertFalse(LanternUtils.isCensored("200.21.225.82")); // Columbia
        assertTrue(LanternUtils.isCensored("212.95.136.18")); // Iran
    }
}
