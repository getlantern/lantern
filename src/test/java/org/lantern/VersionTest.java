package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.File;

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

        final File props = new File(LanternClientConstants.LOG4J_PROPS_PATH);
        // Tests typically run SNAPSHOT versions, except when using mvn release.
        if (props.isFile()) {
            assertTrue(LanternClientConstants.isDevMode());
        } else {
            assertFalse(LanternClientConstants.isDevMode());
        }
    }
}
