package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.File;

import org.apache.commons.io.FileUtils;
import org.junit.BeforeClass;
import org.junit.Test;

import com.google.inject.Guice;
import com.google.inject.Injector;


public class FirefoxExtensionTest {

    private static Configurator configurator;
    
    @BeforeClass
    public static void setup() throws Exception {
        final Injector injector = Guice.createInjector(new LanternModule());
        
        configurator = injector.getInstance(Configurator.class);
    }

    @Test public void testCopy() throws Exception {
        final String extName = "lantern@getlantern.org";
        final File dest = new File(configurator.getExtensionDir(), extName);

        FileUtils.deleteDirectory(dest);
        
        configurator.copyFireFoxExtension();
        assertTrue("Did not create directory!", dest.isDirectory());
        dest.delete();
    }
}
