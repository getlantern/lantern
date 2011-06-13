package org.lantern;

import static org.junit.Assert.assertTrue;

import java.util.Arrays;
import java.util.Collection;

import org.junit.Test;

public class WhitelistTest {

    @Test public void testWhitelisted() throws Exception {
        final Collection<String> whitelist = 
            Arrays.asList("nytimes.com", "facebook.com", "google.com");
        boolean whitelisted = 
            Whitelist.isWhitelisted(
                "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            Whitelist.isWhitelisted(
                "http://www.nytimes.com/", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            Whitelist.isWhitelisted(
                "www.facebook.com:443", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            Whitelist.isWhitelisted(
                "https://s-static.ak.facebook.com", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
            
    }
}
