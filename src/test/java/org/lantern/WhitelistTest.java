package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.io.File;

import org.apache.commons.lang.math.RandomUtils;
import org.junit.Test;


public class WhitelistTest {

    
    @Test
    public void testWhitelist() throws Exception {
        final File settingsFile = settingsFile();
        final SettingsIo io = new SettingsIo(settingsFile);
        final Settings settings = io.read();
        final Whitelist whitelist = settings.getWhitelist();
        
        
        assertTrue(whitelist.isWhitelisted("www.facebook.com:443"));
        assertTrue(whitelist.isWhitelisted("avaaz.org"));
        assertTrue(whitelist.isWhitelisted("getlantern.org"));
        assertFalse(whitelist.isWhitelisted(
            "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg"));
        assertFalse(whitelist.isWhitelisted("http://www.nytimes.com/"));
        assertTrue(whitelist.isWhitelisted("www.facebook.com:443"));
        assertTrue(whitelist.isWhitelisted("https://s-static.ak.facebook.com"));
        
        whitelist.addEntry("nytimes.com");
        whitelist.removeEntry("avaaz.org");
        whitelist.removeEntry("getlantern.org");

        //final SettingsIo io = LanternHub.settingsIo();
        io.write(settings);
        final Settings read2 = io.read();
        final Whitelist readWhitelist = read2.getWhitelist();
        
        assertTrue(readWhitelist.isWhitelisted(
            "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg"));
        assertTrue(readWhitelist.isWhitelisted("http://www.nytimes.com/"));
        assertFalse(readWhitelist.isWhitelisted("avaaz.org"));
        assertTrue(readWhitelist.isWhitelisted("getlantern.org"));
    }
    
    private File settingsFile() {
        return testFile("settings.json");
    }

    private File plist() {
        return testFile("plist");
    }

    private File testFile(final String name) {
        final File temp = new File(System.getProperty("java.io.tmpdir"), 
            String.valueOf(RandomUtils.nextInt()) + "." + name);
        temp.deleteOnExit();
        return temp;
    }
}
