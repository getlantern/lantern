package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.File;

import org.junit.Test;


public class FirefoxExtensionTest {

    @Test public void testCopy() throws Exception {
        final File dest = Configurator.copyFireFoxExtension();
        assertTrue("Did not create directory!", dest.isDirectory());
        dest.delete();
    }
}
