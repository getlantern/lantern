package org.lantern;

import java.net.UnknownHostException;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.packet.Presence;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.httpseverywhere.HttpsEverywhere.HttpsRuleSet;
import org.lastbamboo.common.stun.client.PublicIpAddress;
import org.littleshoot.util.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Function;
import com.google.common.collect.Maps;

/**
 * Default class containing configuration settings and data.
 */
public class DefaultConfigApi implements ConfigApi, LanternUpdateListener,
    PresenceListener {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final Map<String, Function<String, String>> configFuncs =
        Maps.newConcurrentMap();

    private LanternUpdate lanternUpdate = 
        new LanternUpdate(new HashMap<String, String>());
    
    private final Map<String, Presence> presences = 
        new ConcurrentHashMap<String, Presence>();
    
    /**
     * Creates a new instance of the API. There should only be one.
     */
    public DefaultConfigApi() {
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
        LanternHub.notifier().addUpdateListener(this);
        LanternHub.notifier().addPresenceListener(this);
    }
    
    @Override
    public String roster() {
        return LanternUtils.jsonify(this.presences);
    }

    @Override
    public String whitelist() {
        log.info("Accessing whitelist");
        final Collection<WhitelistEntry> wl = 
            LanternHub.whitelist().getWhitelist();
        return LanternUtils.jsonify(wl);
    }

    @Override
    public String addToWhitelist(final String body) {
        LanternHub.whitelist().addEntry(body.trim());
        return whitelist();
    }

    @Override
    public String removeFromWhitelist(final String body) {
        LanternHub.whitelist().removeEntry(body.trim());
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
        data.put("internet", getInternet());
        data.put("whitelist", LanternHub.whitelist());
        data.put("roster", presences);
        data.put("httpsEverywhere", HttpsEverywhere.getRules());
        data.put("censored", LanternHub.censored().getCensored());
        data.put("system", getSystem());
        //data.put("connectivity", 
        //    LanternHub.connectivityTracker().getConnectivityStatus());
        //data.put("port", LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        //data.put("version", LanternConstants.VERSION);
        //data.put("systemProxy", Configurator.isProxying());
        
        //data.put("startAtLogin", Configurator.isStartAtLogin()); 
        return LanternUtils.jsonify(data);
    }
    
    private Map<String, Object> getInternet() {
        final Map<String, Object> internet = 
            new LinkedHashMap<String, Object>();
        final Map<String, Object> ip = new TreeMap<String, Object>();
        ip.put("public", new PublicIpAddress().getPublicIpAddress());
        try {
            ip.put("private", NetworkUtils.getLocalHost());
        } catch (final UnknownHostException e) {
            log.info("Could not look up private IP", e);
        }
        internet.put("ip", ip);
        return internet;
    }

    private Map<String, Object> getSystem() {
        final Map<String, Object> system = new LinkedHashMap<String, Object>();
        system.put("location", LanternHub.censored().countryCode());
        system.put("systemProxy", Configurator.isProxying());
        system.put("startAtLogin", Configurator.isStartAtLogin());
        system.put("port", LanternConstants.LANTERN_LOCALHOST_HTTP_PORT);
        system.put("version", LanternConstants.VERSION);
        system.put("connectivity", 
                LanternHub.connectivityTracker().getConnectivityStatus());
        system.put("updateData", this.lanternUpdate); 
        system.put("properties", System.getProperties());
        
        return system;
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
    public void onUpdate(final LanternUpdate lu) {
        this.lanternUpdate = lu;
    }

    @Override
    public void onPresence(final String address, final Presence presence) {
        this.presences.put(address, presence);
    }

    @Override
    public void removePresence(final String address) {
        this.presences.remove(address);
    }
}
