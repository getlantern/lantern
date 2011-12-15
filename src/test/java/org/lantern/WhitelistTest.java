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
        LanternHub.whitelist().reset();
        LanternHub.whitelist().removeEntry("twitter.com");
        assertEquals(1, LanternHub.whitelist().getRemovals().size());
        final String json = LanternHub.whitelist().getRemovalsAsJson();
        assertTrue(json.contains("twitter.com"));
        JSONArray array = (JSONArray) new JSONParser().parse(json);
        assertEquals(1, array.size());
        LanternHub.whitelist().whitelistReported();
        assertEquals(0, LanternHub.whitelist().getRemovals().size());
        
        array = (JSONArray) new JSONParser().parse(LanternHub.whitelist().getRemovalsAsJson());
        assertEquals(0, array.size());
    }
    
    @Test public void testAdditions() throws Exception {
        LanternHub.whitelist().reset();
        LanternHub.whitelist().addEntry("different.com");
        //Whitelist.removeEntry("twitter.com");
        assertEquals(1, LanternHub.whitelist().getAdditions().size());
        final String json = LanternHub.whitelist().getAdditionsAsJson();
        assertTrue(json.contains("different.com"));
        JSONArray array = (JSONArray) new JSONParser().parse(json);
        assertEquals(1, array.size());
        LanternHub.whitelist().whitelistReported();
        assertEquals(0, LanternHub.whitelist().getAdditions().size());
        
        array = (JSONArray) new JSONParser().parse(LanternHub.whitelist().getAdditionsAsJson());
        assertEquals(0, array.size());
    }
    
    @Test public void testWhitelisted() throws Exception {
        final Collection<WhitelistEntry> whitelist = 
            Arrays.asList(new WhitelistEntry("nytimes.com"), 
                new WhitelistEntry("facebook.com"), 
                new WhitelistEntry("google.com"));
        boolean whitelisted = 
            LanternHub.whitelist().isWhitelisted(
                "http://graphics8.nytimes.com/adx/images/ADS/25/67/ad.256707/MJ_NYT_Text-Right.jpg", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            LanternHub.whitelist().isWhitelisted(
                "http://www.nytimes.com/", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            LanternHub.whitelist().isWhitelisted(
                "www.facebook.com:443", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
        
        whitelisted = 
            LanternHub.whitelist().isWhitelisted(
                "https://s-static.ak.facebook.com", 
                whitelist);
        
        assertTrue("Should be whitelisted", whitelisted);
            
    }
    
    @Test public void testWhitelistFile() throws Exception {
        final boolean wl = LanternHub.whitelist().isWhitelisted(
            "http://www.whatismyip.com");
        assertTrue(wl);
    }
}
