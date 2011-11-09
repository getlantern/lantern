package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.util.Iterator;

import org.apache.commons.lang.StringUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.junit.Test;


public class StatsTrackerTest {

    //@Test 
    public void testGoogleContentRemovalRequests() throws Exception {
        final StatsTracker st = new StatsTracker();
        //final String goog = st.googleContentRemovalProductReason();
        final String goog = st.googleContentRemovalRequests();
        final JSONObject googJson = (JSONObject) JSONValue.parse(goog);
        final JSONObject norwayJson = (JSONObject) googJson.get("NO");
        final String trans = (String) norwayJson.get(
            "Percentage of removal requests fully or partially complied with");
        assertEquals("100", trans);
    }
    
    //@Test 
    public void testGoogleContentRemovalProductReason() throws Exception {
        final StatsTracker st = new StatsTracker();
        final String goog = st.googleContentRemovalProductReason();
        final JSONObject googJson = (JSONObject) JSONValue.parse(goog);
        final JSONObject usJson = (JSONObject) googJson.get("US");
        assertTrue(usJson != null);
        final JSONObject yt = (JSONObject) usJson.get("YouTube");
        assertTrue("No YouTube in "+usJson.toJSONString(), yt != null);
    }
    
    @Test
    public void testCountryData() throws Exception {
        final StatsTracker st = new StatsTracker();
        final String china = st.countryData("CN");
        final JSONObject chinaJson2 = (JSONObject) JSONValue.parse(china);
        
        assertTrue(chinaJson2.containsKey("lantern"));
        assertTrue(chinaJson2.containsKey("oni"));
        
        final String norway = st.countryData("NO");
        final JSONObject noJson = (JSONObject) JSONValue.parse(norway);
        
        assertTrue(noJson.containsKey("lantern"));
        assertTrue(noJson.containsKey("oni"));
        if (!noJson.containsKey("google-content-removal-requests-by-product-and-reason.csv")) {
            System.out.println("No JSON in "+noJson.toJSONString());
        }
        assertTrue("No JSON in ", noJson.containsKey("google-content-removal-requests-by-product-and-reason.csv"));
    }
    
    //@Test 
    public void testOni() throws Exception {
        final StatsTracker st = new StatsTracker();
        
        final String jsonString = st.toJson();
        //System.out.println(jsonString);
        final JSONObject json = (JSONObject) JSONValue.parse(jsonString);
        final JSONArray countries = (JSONArray) json.get("countries");
        boolean foundChina = false;
        boolean foundNorway = false;
        final Iterator<JSONObject> iter = countries.iterator();
        while (iter.hasNext()) {
            final JSONObject obj = iter.next();
            final String code = (String) obj.get("code");
            assertTrue(StringUtils.isNotBlank(code));
            if (code.equals("CN")) {
                foundChina = true;
                final JSONObject oniTest = (JSONObject) obj.get("oni");
                assertTrue("no oni??", oniTest != null);
            }
            if (code.equals("NO")) {
                foundNorway = true;
                final JSONObject oniTest = (JSONObject) obj.get("oni");
                assertTrue("no oni??", oniTest != null);
                final JSONObject goog1 = (JSONObject) obj.get("google-content-removal-requests-by-product-and-reason.csv");
                assertTrue("no google in "+obj.toJSONString(), goog1 != null);
                //final JSONObject goog2 =
                //    (JSONObject) goog1.get("google-content-removal-requests-by-product-and-reason.csv");
                //assertTrue("no google subdata?", goog2 != null);
            }
        }
        assertTrue(foundNorway);
        assertTrue(foundChina);
        
        final String oni = st.oniJson();
        final JSONObject oniJson = (JSONObject) JSONValue.parse(oni);
        final JSONObject chinaJson = (JSONObject) oniJson.get("CN");
        final String trans = (String) chinaJson.get("transparency");
        assertEquals("Low", trans);
        
        final String china = st.countryData("CN");
        final JSONObject chinaJson2 = (JSONObject) JSONValue.parse(china);
        
        assertTrue(chinaJson2.containsKey("lantern"));
        assertTrue(chinaJson2.containsKey("oni"));
    }
}
