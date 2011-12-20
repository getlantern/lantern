package org.lantern;

import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.jivesoftware.smack.packet.Presence;
import org.lantern.httpseverywhere.HttpsEverywhere;
import org.lantern.httpseverywhere.HttpsEverywhere.HttpsRuleSet;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Default class containing configuration settings and data.
 */
public class DefaultConfigApi implements ConfigApi, PresenceListener {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private final Map<String, Presence> presences = 
        new ConcurrentHashMap<String, Presence>();
    
    /**
     * Creates a new instance of the API. There should only be one.
     */
    public DefaultConfigApi() {
        LanternHub.pubSub().addPresenceListener(this);
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
    public String configAsJson() {
        return LanternUtils.jsonify(config());
    }
    
    @Override
    public Map<String, Object> config() {
        final Map<String, Object> data = new LinkedHashMap<String, Object>();
        data.put("system", LanternHub.systemInfo());
        data.put("user", LanternHub.userInfo());
        data.put("whitelist", LanternHub.whitelist());
        data.put("roster", presences);
        data.put("httpsEverywhere", HttpsEverywhere.getRules());
        return data;
    }
    
    /*
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
        system.put("internet", getInternet());
        system.put("platform", getPlatform());
        return system;
    }
    */

    /*
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
        return configAsJson();
    }
    */

    @Override
    public void onPresence(final String address, final Presence presence) {
        this.presences.put(address, presence);
    }

    @Override
    public void removePresence(final String address) {
        this.presences.remove(address);
    }

    @Override
    public void presencesUpdated() {
        // Nothing to do.
    }

    @Override
    public String setConfig(Map<String, String> args) {
        return "";
    }
}
