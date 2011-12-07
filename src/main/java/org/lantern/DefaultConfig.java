package org.lantern;

import java.lang.reflect.Type;
import java.util.Collection;

import org.jivesoftware.smack.packet.Presence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonSerializationContext;
import com.google.gson.JsonSerializer;

/**
 * Default class containing configuration settings and data.
 */
public class DefaultConfig implements Config {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Override
    public String roster() {
        final XmppHandler handler = LanternHub.xmppHandler();
        final Collection<Presence> presences = handler.getPresences();
        final GsonBuilder gb = new GsonBuilder();
        gb.registerTypeAdapter(Presence.class, new JsonSerializer<Presence>() {
            @Override
            public JsonElement serialize(final Presence pres, final Type typs,
                final JsonSerializationContext jsc) {
                final JsonObject obj = new JsonObject();
                obj.addProperty("user", pres.getFrom());
                obj.addProperty("type", pres.getType().name());
                return obj;
            }
        });
        
        final Gson gson = gb.create();
        return gson.toJson(presences);
    }
}
