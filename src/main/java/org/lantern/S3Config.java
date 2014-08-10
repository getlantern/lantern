package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.apache.commons.codec.Charsets;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.annotate.JsonIgnoreProperties;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.proxy.FallbackProxy;
import org.lantern.proxy.pt.FlashlightMasquerade;
import org.lantern.proxy.pt.FlashlightProxy;
import org.lantern.proxy.pt.MasqueradeListener;
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
            new FlashlightMasquerade(DEFAULT_HOSTS_TO_CERTS, new MasqueradeListener() {
                
                @Override
                public void onTestedAndVerifiedHost(String host) {
                    synchronized (TESTED_AND_VERIFIED_HOSTS) {
                        LOG.info("Adding tested and verified host: {}", host);
                        TESTED_AND_VERIFIED_HOSTS.add(host);
                    }
                }
            });

    /**
     * This is a flashlight proxy that internally handles things like 
     * dynamically determining the masquerade host to use.
     */
    private final FallbackProxy flashlightProxy = 
            new FlashlightProxy("roundrobin.getiantem.org", 1, MASQUERADE);


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
        all.addAll(getFallbacks());
        all.add(flashlightProxy);
        return all;
    }

    private static final List<String> TESTED_AND_VERIFIED_HOSTS = 
            new LinkedList<String>();

    @JsonIgnore
    public static String getMasqueradeHost() {
        if (TESTED_AND_VERIFIED_HOSTS.isEmpty()) {
            LOG.warn("Not using tested and verified host...");
            final Set<String> hosts = DEFAULT_HOSTS_TO_CERTS.keySet();
            return hosts.iterator().next();
        }
        synchronized (TESTED_AND_VERIFIED_HOSTS) {
            Collections.shuffle(TESTED_AND_VERIFIED_HOSTS);
            return TESTED_AND_VERIFIED_HOSTS.iterator().next();
        }
    }
}
