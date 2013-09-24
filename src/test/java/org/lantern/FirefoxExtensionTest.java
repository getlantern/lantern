package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.File;

import org.apache.commons.io.FileUtils;
import org.junit.Test;


public class FirefoxExtensionTest {

    @Test public void testCopy() throws Exception {
        final String extName = "lantern@getlantern.org";
        final LanternModule module = new LanternModule(new String[]{});
        final File dest = new File(module.getExtensionDir(), extName);

        FileUtils.deleteDirectory(dest);
        
        module.copyFireFoxExtension();
        assertTrue("Did not create directory!", dest.isDirectory());
        dest.delete();
    }
}
