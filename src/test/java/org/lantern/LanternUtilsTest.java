package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.Collection;

import org.apache.commons.lang.SystemUtils;
import org.junit.Test;

/**
 * Test for Lantern utilities.
 */
public class LanternUtilsTest {
    
    @Test public void testOsFamily() throws Exception {
        System.out.println("OS NAME: "+SystemUtils.OS_NAME);
        System.out.println("OS ARCH: "+SystemUtils.OS_ARCH);
        System.out.println("ARCH: "+System.getProperty("sun.arch.data.model"));
        //System.out.println("ARCH: "+System.getProperty("sun.arch.data.model"));
    }
    
    @Test public void testToHttpsCandidates() throws Exception {
        Collection<String> candidates = 
            LanternUtils.toHttpsCandidates("http://www.google.com");
        assertTrue(candidates.contains("www.google.com"));
        assertTrue(candidates.contains("*.google.com"));
        assertTrue(candidates.contains("www.*.com"));
        assertTrue(candidates.contains("www.google.*"));
        assertEquals(4, candidates.size());
        
        candidates = 
            LanternUtils.toHttpsCandidates("http://test.www.google.com");
        assertTrue(candidates.contains("test.www.google.com"));
        assertTrue(candidates.contains("*.www.google.com"));
        assertTrue(candidates.contains("*.google.com"));
        assertTrue(candidates.contains("test.*.google.com"));
        assertTrue(candidates.contains("test.www.*.com"));
        assertTrue(candidates.contains("test.www.google.*"));
        assertEquals(6, candidates.size());
        //assertTrue(candidates.contains("*.com"));
        //assertTrue(candidates.contains("*"));
    }
    
    @Test public void testCensored() throws Exception {
        final boolean censored = CensoredUtils.isCensored();
        assertFalse("Censored?", censored);
        assertTrue(CensoredUtils.isExportRestricted("78.110.96.7")); // Syria
        
        
        assertTrue(CensoredUtils.isCensored("78.110.96.7")); // Syria
        assertFalse(CensoredUtils.isCensored("151.38.39.114")); // Italy
        assertFalse(CensoredUtils.isCensored("12.25.205.51")); // USA
        assertFalse(CensoredUtils.isCensored("200.21.225.82")); // Columbia
        assertTrue(CensoredUtils.isCensored("212.95.136.18")); // Iran
    }
}
