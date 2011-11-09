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

    @Test public void testOni() throws Exception {
        final StatsTracker st = new StatsTracker();
        
        final String jsonString = st.toJson();
        //System.out.println(jsonString);
        final JSONObject json = (JSONObject) JSONValue.parse(jsonString);
        final JSONArray countries = (JSONArray) json.get("countries");
        boolean foundChina = false;
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
        }
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
