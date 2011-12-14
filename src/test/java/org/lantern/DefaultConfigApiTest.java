package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.apache.commons.lang.StringUtils;
import org.junit.Test;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

public class DefaultConfigApiTest {

    @Test 
    public void testGlobalConfig() throws Exception {
        final ConfigApi conf = new DefaultConfigApi();
        final String json = conf.config();
        final JsonParser parser = new JsonParser();
        final JsonElement parsed = parser.parse(json);
        final JsonObject read = parsed.getAsJsonObject();
        System.out.println(read);
        final JsonElement elem = read.get("connectivity");
        assertTrue(StringUtils.isNotBlank(elem.getAsString()));
        
        final JsonElement port = read.get("port");
        assertEquals(LanternConstants.LANTERN_LOCALHOST_HTTP_PORT, port.getAsInt());
    }
    
    @Test 
    public void testWhitelist() throws Exception {
        final ConfigApi conf = new DefaultConfigApi();
        final String wl = conf.whitelist();
        
        final JsonParser parser = new JsonParser();
        final JsonElement parsed = parser.parse(wl);
        final JsonObject read = parsed.getAsJsonObject();
        final JsonElement avaaz = read.get("avaaz.org");
        assertTrue(avaaz != null);
    }
    
    @Test 
    public void testHttpsEverywhere() throws Exception {
        final ConfigApi conf = new DefaultConfigApi();
        final String json = conf.httpsEverywhere();
        final JsonParser parser = new JsonParser();
        final JsonElement parsed = parser.parse(json);
        final JsonObject read = parsed.getAsJsonObject();
        final JsonElement avaaz = read.get("avaaz.org");
        assertTrue(avaaz != null);
        final JsonElement rules = avaaz.getAsJsonObject().get("rules");
        assertTrue(rules != null);
    }
}
