package org.lantern;

import java.lang.reflect.Type;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.packet.Presence;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.httpseverywhere.HttpsEverywhere.HttpsRuleSet;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Function;
import com.google.common.collect.Maps;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonSerializationContext;
import com.google.gson.JsonSerializer;

/**
 * Default class containing configuration settings and data.
 */
public class DefaultConfigApi implements ConfigApi, UpdateListener {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final GsonBuilder gb = new GsonBuilder();

    private Map<String, String> updateData = new HashMap<String, String>();
    
    private final Map<String, Function<String, String>> configFuncs =
        Maps.newConcurrentMap();
    
    /**
     * Creates a new instance of the API. There should only be one.
     */
    public DefaultConfigApi() {
        updateData.put(LanternConstants.UPDATE_VERSION_KEY, 
            LanternConstants.VERSION);
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
        configFuncs.put("systemProxy", new Function<String, String>() {
            @Override
            public String apply(final String input) {
                if (LanternUtils.isTrue(input)) {
                    Configurator.startProxying();
                } else if (LanternUtils.isFalse(input)) {
                    Configurator.stopProxying();
                }
                return "";
            }
        });
        configFuncs.put("startAtLogin", new Function<String, String>() {
            @Override
            public String apply(final String input) {
                if (LanternUtils.isTrue(input)) {
                    Configurator.startAtLogin(true);
                } else if (LanternUtils.isFalse(input)) {
                    Configurator.startAtLogin(false);
                }
                return "";
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
        final Collection<WhitelistEntry> wl = Whitelist.getWhitelist();
        final Map<WhitelistEntry, Map<String,Object>> all = 
            new LinkedHashMap<WhitelistEntry, Map<String,Object>>();
        for (final WhitelistEntry cur : wl) {
            final Map<String,Object> site = new HashMap<String,Object>();
            site.put("required", Whitelist.required(cur));
            //site.put("httpsRules", 
            //    HttpsEverywhere.getApplicableRuleSets("http://"+cur));
            all.put(cur, site);
        }
        
        return LanternUtils.jsonify(all);
    }

    @Override
    public String addToWhitelist(final String body) {
        Whitelist.addEntry(body.trim());
        return whitelist();
    }

    @Override
    public String removeFromWhitelist(final String body) {
        Whitelist.removeEntry(body.trim());
        return whitelist();
    }

    @Override
    public String addToTrusted(final String body) {
        final TrustedContactsManager tcm = 
            LanternHub.getTrustedContactsManager();
        tcm.addTrustedContact(body.trim());
        return roster();
    }

    @Override
    public String removeFromTrusted(final String body) {
        final TrustedContactsManager tcm = 
            LanternHub.getTrustedContactsManager();
        tcm.removeTrustedContact(body.trim());
        return roster();
    }
    
    @Override
    public String httpsEverywhere() {
        final Map<String, HttpsRuleSet> rules = HttpsEverywhere.getRules();
        return LanternUtils.jsonify(rules);
    }

    @Override
    public String config() {
        final Map<String, Object> data = new LinkedHashMap<String, Object>();
        data.put("connectivity", 
            LanternHub.connectivityTracker().getConnectivityStatus());
        data.put("port", LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        data.put("version", LanternConstants.VERSION);
        data.put("systemProxy", Configurator.isProxying());
        data.put("updateData", this.updateData); 
        data.put("startAtLogin", Configurator.isStartAtLogin()); 
        return LanternUtils.jsonify(data);
    }
    
    @Override
    public String setConfig(final Map<String, String> args) {
        final Set<String> keys = args.keySet();
        for (final String key : keys) {
            log.info("Processing config key: {}", key);
            final Function<String, String> func = configFuncs.get(key);
            if (func != null) {
                final String val = args.get(key);
                if (StringUtils.isNotBlank(val)) {
                    func.apply(val.trim());
                }
            }
        }
        return config();
    }

    @Override
    public void onUpdate(final Map<String, String> updateData) {
        this.updateData = updateData;
    }
}
