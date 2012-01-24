package org.lantern;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;


public class WhitelistTest {

    
    @Test
    public void testSettings() throws Exception {
        final Whitelist whitelist = new Whitelist();
        
        
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

        //io.write(read);
        //final Settings read2 = io.read();
        //final Whitelist readWhitelist = read2.getWhitelist();
        
        assertTrue(whitelist.isWhitelisted(
            "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg"));
        assertTrue(whitelist.isWhitelisted("http://www.nytimes.com/"));
        assertFalse(whitelist.isWhitelisted("avaaz.org"));
        assertTrue(whitelist.isWhitelisted("getlantern.org"));
    }
}
