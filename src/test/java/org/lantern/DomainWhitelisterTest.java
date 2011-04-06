package org.lantern;

import static org.junit.Assert.*;

import java.util.Arrays;
import java.util.Collection;

import org.junit.Test;


public class DomainWhitelisterTest {

    @Test public void testWhitelisted() throws Exception {
        final Collection<String> whitelist = Arrays.asList("nytimes.com");
        boolean whitelisted = 
            DomainWhitelister.isWhitelisted(
                "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            DomainWhitelister.isWhitelisted(
                "http://www.nytimes.com/", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            DomainWhitelister.isWhitelisted(
                "http://www.nytimes.com", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            DomainWhitelister.isWhitelisted(
                "http://nytimes.com", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
            
    }
}
