package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.junit.Test;


public class StatsTrackerTest {

    @Test public void testOni() throws Exception {
        final StatsTracker st = new StatsTracker();
        
        final String json = st.toJson();
        //System.out.println(json);
        
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
