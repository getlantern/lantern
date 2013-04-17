package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.apache.commons.lang3.StringUtils;
import org.junit.Test;
import org.lantern.state.Version;
import org.lantern.state.Version.Installed;

public class VersionTest {
    @Test
    public void testVersion() {
        assertFalse(StringUtils.isBlank(LanternClientConstants.VERSION));

        Version version = new Version();
        Installed installed = version.getInstalled();
        assertFalse(StringUtils.isBlank(installed.getGit()));

        // we will never be running the tests from an installer-generated
        // version
        assertTrue(LanternClientConstants.isDevMode());
    }
}
