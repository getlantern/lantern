package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

/**
 * Test for Lantern utilities.
 */
public class LanternUtilsTest {

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
