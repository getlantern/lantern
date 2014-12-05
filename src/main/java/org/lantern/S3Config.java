package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Collection;
import java.util.HashSet;
import java.util.Map;

import org.apache.commons.codec.Charsets;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.annotate.JsonIgnoreProperties;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.proxy.FallbackProxy;
import org.lantern.proxy.pt.FlashlightMasquerade;
import org.lantern.proxy.pt.FlashlightProxy;
import org.lantern.state.Model.Persistent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.io.Files;

@JsonIgnoreProperties(ignoreUnknown = true)
public class S3Config extends BaseS3Config {

    private static final Logger LOG = LoggerFactory.getLogger(S3Config.class);
    
    static {
        final File cfcerts = new File("cloudflare-certs");
        final File[] certs = cfcerts.listFiles();
        for (final File cert : certs) {
            LOG.info("Loading cert...{}", cert);
            try {
                DEFAULT_HOSTS_TO_CERTS.put(cert.getName(), 
                        Files.toString(cert, Charsets.UTF_8).trim());
            } catch (IOException e) {
                LOG.error("Could not load cert?", e);
            }
        }
    }

    public static final FlashlightMasquerade MASQUERADE = 
            new FlashlightMasquerade(DEFAULT_HOSTS_TO_CERTS);
    
    /**
     * This is a flashlight proxy that internally handles things like 
     * dynamically determining the masquerade host to use.
     */
    private static final FallbackProxy FLASHLIGHT_PROXY = 
            new FlashlightProxy("roundrobin.getiantem.org", 1, MASQUERADE,
                    DEFAULT_FLASHLIGHT_CLOUDCONFIG,
                    DEFAULT_FLASHLIGHT_CLOUDCONFIG_CA);


    /**
     * We override this simply to avoid writing the JSON for tons of certs to
     * the UI.
     */
    @JsonView({Persistent.class})
    @Override
    public Map<String, String> getMasqueradeHostsToCerts() {
        return super.getMasqueradeHostsToCerts();
    }
    
    /**
     * This is a special method of the subclass that's a result of us 
     * dynamically selecting the flashlight proxy every time. With that 
     * dynamism, the config would always appear to be changed with every new
     * fetch. This way, the uniquely selected flashlight proxy won't throw
     * off hashcode and equals calls.
     * 
     * @return All fallback proxies, including the dynamically selected 
     * flashlight proxy.
     */
    @JsonIgnore
    public Collection<FallbackProxy> getAllFallbacks() {
        final Collection<FallbackProxy> all = new HashSet<FallbackProxy>();
        if (!LanternClientConstants.FORCE_FLASHLIGHT) {
            all.addAll(getFallbacks());
        }
        all.add(FLASHLIGHT_PROXY);
        return all;
    }

    @JsonIgnore
    public static String getMasqueradeHost() {
        return FLASHLIGHT_PROXY.getWanHost();
    }
}
