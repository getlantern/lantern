package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.File;

import org.apache.commons.io.FileUtils;
import org.junit.Test;


public class FirefoxExtensionTest {

    @Test public void testCopy() throws Exception {
        final String extName = "lantern@getlantern.org";
        final File dest = new File(LanternHub.configurator().getExtensionDir(), extName);

        FileUtils.deleteDirectory(dest);
        
        LanternHub.configurator().copyFireFoxExtension();
        assertTrue("Did not create directory!", dest.isDirectory());
        dest.delete();
    }
}
