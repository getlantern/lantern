package org.lantern;

import java.lang.reflect.Type;
import java.util.Collection;

import org.jivesoftware.smack.packet.Presence;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonSerializationContext;
import com.google.gson.JsonSerializer;

/**
 * Default class containing configuration settings and data.
 */
public class DefaultConfig implements Config {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final GsonBuilder gb = new GsonBuilder();
    
    public DefaultConfig() {
        final TrustedContactsManager tcm = 
            LanternHub.getTrustedContactsManager();
        gb.registerTypeAdapter(Presence.class, new JsonSerializer<Presence>() {
            @Override
            public JsonElement serialize(final Presence pres, final Type type,
                final JsonSerializationContext jsc) {
                final JsonObject obj = new JsonObject();
                obj.addProperty("user", pres.getFrom());
                obj.addProperty("type", pres.getType().name());
                obj.addProperty("trusted", tcm.isTrusted(pres.getFrom()));
                return obj;
            }
        });
        
    }
    
    @Override
    public String roster() {
        final XmppHandler handler = LanternHub.xmppHandler();
        final Collection<Presence> presences = handler.getPresences();
        final Gson gson = gb.create();
        return gson.toJson(presences);
    }

    @Override
    public String whitelist() {
        log.info("Accessing whitelist");
        final Collection<String> wl = Whitelist.getWhitelist();
        final JSONArray ja = new JSONArray();
        for (final String site : wl) {
            final JSONObject jo = new JSONObject();
            jo.put("base", site);
            jo.put("required", Whitelist.required(site));
            ja.add(jo);
        }
        return ja.toJSONString();
    }
}
