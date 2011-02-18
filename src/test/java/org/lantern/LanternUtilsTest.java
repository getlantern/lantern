package org.lantern;

import static org.junit.Assert.*;

import org.junit.Test;

/**
 * Test for Lantern utilities.
 */
public class LanternUtilsTest {

    @Test public void testCensored() throws Exception {
        final boolean censored = LanternUtils.isCensored();
        assertFalse("Censored?", censored);
    }
}
