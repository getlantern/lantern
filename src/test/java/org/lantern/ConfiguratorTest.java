package org.lantern;

import static org.junit.Assert.*;

import java.io.File;

import org.apache.commons.io.FileUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Tests for the configurator.
 */
public class ConfiguratorTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void testStartAtLogin() throws Exception {
        if (!LanternConstants.LAUNCHD_PLIST.isFile()) {
            log.info("No plist file - not installed or on different OS?");
            return;
        }
        final File temp = 
            File.createTempFile(String.valueOf(hashCode()), "test");
        temp.deleteOnExit();
        FileUtils.copyFile(LanternConstants.LAUNCHD_PLIST, temp);
        final String cur = FileUtils.readFileToString(temp, "UTF-8");
        
        assertTrue(cur.contains("<true/>") || cur.contains("<false/>"));
        if (cur.contains("<true/>")) {
            assertFalse(cur.contains("<false/>"));
            Configurator.setStartAtLogin(temp, false);
            final String newFile = FileUtils.readFileToString(temp, "UTF-8");
            assertTrue(newFile.contains("<false/>"));
        } else if (cur.contains("<false/>")) {
            assertFalse(cur.contains("<true/>"));
            Configurator.setStartAtLogin(temp, true);
            final String newFile = FileUtils.readFileToString(temp, "UTF-8");
            assertTrue(newFile.contains("<true/>"));
        }
    }
}
