package org.lantern;

import static org.junit.Assert.assertTrue;

import org.junit.Test;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

public class DefaultConfigTest {

    @Test public void testWhitelist() throws Exception {
        final Config conf = new DefaultConfig();
        final String wl = conf.whitelist();
        final JsonParser parser = new JsonParser();
        final JsonArray json = parser.parse(wl).getAsJsonArray();
        boolean hasTwitter = false;
        for (int i = 0; i < json.size(); i++) {
            final JsonElement je = json.get(i);
            final JsonObject obj = je.getAsJsonObject();
            final String site = obj.get("base").getAsString();
            if (site.contains("twitter.com")) {
                hasTwitter = true;
            }
        }
        assertTrue(hasTwitter);
        
    }
}
