package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.util.Arrays;
import java.util.Collection;

import org.json.simple.JSONArray;
import org.json.simple.parser.JSONParser;
import org.junit.Test;

public class WhitelistTest {

    @Test public void testRemovals() throws Exception {
        Whitelist.reset();
        Whitelist.removeEntry("twitter.com");
        assertEquals(1, Whitelist.getRemovals().size());
        final String json = Whitelist.getRemovalsAsJson();
        assertTrue(json.contains("twitter.com"));
        JSONArray array = (JSONArray) new JSONParser().parse(json);
        assertEquals(1, array.size());
        Whitelist.whitelistReported();
        assertEquals(0, Whitelist.getRemovals().size());
        
        array = (JSONArray) new JSONParser().parse(Whitelist.getRemovalsAsJson());
        assertEquals(0, array.size());
    }
    
    @Test public void testAdditions() throws Exception {
        Whitelist.reset();
        Whitelist.addEntry("different.com");
        //Whitelist.removeEntry("twitter.com");
        assertEquals(1, Whitelist.getAdditions().size());
        final String json = Whitelist.getAdditionsAsJson();
        assertTrue(json.contains("different.com"));
        JSONArray array = (JSONArray) new JSONParser().parse(json);
        assertEquals(1, array.size());
        Whitelist.whitelistReported();
        assertEquals(0, Whitelist.getAdditions().size());
        
        array = (JSONArray) new JSONParser().parse(Whitelist.getAdditionsAsJson());
        assertEquals(0, array.size());
    }
    
    @Test public void testWhitelisted() throws Exception {
        final Collection<WhitelistEntry> whitelist = 
            Arrays.asList(new WhitelistEntry("nytimes.com"), 
                new WhitelistEntry("facebook.com"), 
                new WhitelistEntry("google.com"));
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
    
    @Test public void testWhitelistFile() throws Exception {
        final boolean wl = Whitelist.isWhitelisted("http://www.whatismyip.com");
        assertTrue(wl);
    }
}
