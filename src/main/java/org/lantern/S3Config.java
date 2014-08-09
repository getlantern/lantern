package org.lantern;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Properties;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import org.apache.commons.codec.Charsets;
import org.apache.http.HttpResponse;
import org.codehaus.jackson.annotate.JsonIgnore;
import org.codehaus.jackson.annotate.JsonIgnoreProperties;
import org.codehaus.jackson.map.annotate.JsonView;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.proxy.FallbackProxy;
import org.lantern.proxy.pt.Flashlight;
import org.lantern.state.Model.Persistent;
import org.lantern.util.HostSpoofedHTTPGet.ResponseHandler;
import org.lantern.util.Threads;
import org.littleshoot.util.FiveTuple.Protocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.io.Files;

@JsonIgnoreProperties(ignoreUnknown = true)
public class S3Config extends BaseS3Config {

    private static final Logger LOG = LoggerFactory.getLogger(S3Config.class);
    
    private static Map.Entry<String, String> cachedMasqueradeHost;
    
    /**
     * This is static so that we don't run through the process of selecting
     * it again when a new S3Config object is created (downloaded, for example).
     */
    private static FallbackProxy selectedFlashlightProxy;
    
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
    
    @JsonView({Persistent.class})
    @Override
    public Map<String, String> getMasqueradeHostsToCerts() {
        return super.getMasqueradeHostsToCerts();
    }
    
    private FallbackProxy getFlashlightFallback() {
        if (selectedFlashlightProxy == null) {
            final FallbackProxy proxy = 
                    flashlightProxy("roundrobin.getiantem.org", 1);
            
            // It's possible we've received a proxy that's just random from
            // the list because nothing actually worked. In that case, return
            // it but don't cache it so we'll try again the next time we
            // need one.
            if (TESTED_AND_VERIFIED_HOSTS.isEmpty()) {
                return proxy;
            }
            selectedFlashlightProxy = proxy;
        }
        return selectedFlashlightProxy;
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
        all.add(getFlashlightFallback());
        return all;
    }
    

    // Hard-coded flashlight proxy. This could eventually be replaced by a
    // dynamic value fetched from S3.
    private FallbackProxy flashlightProxy(String host, int priority) {
        FallbackProxy flashlightProxy = new FallbackProxy();
        Properties ptProps = flashlightProps(host);
        flashlightProxy.setPt(ptProps);
        flashlightProxy.setJid(LanternUtils.newURI("flashlight@"
                + ptProps.getProperty(Flashlight.SERVER_KEY)));
        flashlightProxy.setIp(ptProps.getProperty(Flashlight.MASQUERADE_KEY));
        flashlightProxy.setPort(443);
        flashlightProxy.setProtocol(Protocol.TCP);
        flashlightProxy.setPriority(priority);
        return flashlightProxy;
    }

    public Properties flashlightProps(String host) {
        Properties props = new Properties();
        props.setProperty("type", "flashlight");
        props.setProperty(Flashlight.SERVER_KEY, host);
        cachedMasqueradeHost = determineMasqueradeHost();
        final String cert = cachedMasqueradeHost.getValue();
        LOG.info("Using cert: {}", cert);
        props.setProperty(Flashlight.MASQUERADE_KEY, 
                cachedMasqueradeHost.getKey());
        props.setProperty(Flashlight.ROOT_CA_KEY, cert);
        return props;
    }
    
    private static final List<String> TESTED_AND_VERIFIED_HOSTS = 
            new LinkedList<String>();
    
    private Entry<String, String> determineMasqueradeHost() {
        LOG.info("Determining masquerade host to use...");
        
        if (cachedMasqueradeHost != null) {
            return cachedMasqueradeHost;
        }
        final Map<String, String> hostsToCertificates = 
                super.getMasqueradeHostsToCerts();
        // BLOCKED
        // media-fire.org
        // eztv.it
        // 4chan.org
        // porntube.com
        // censor.net.ua
        // eharmony.com
        // mostawesomeoffers.com
        // gameninja.com
        // gamebaby.com
        // zaman.com.tr
        // geenstijl.nl
        // animeflv.net
        // rusvesna.su
        // life.com.tw
        // pingdom.com
        // opencart.com
        // imagetwist.com
        // 4cdn.org
        
        final ExecutorService pool = 
                Threads.newCachedThreadPool("Masquerade-Lookup-");
        final Collection<Callable<Entry<String, String>>> tasks = 
            new ArrayList<Callable<Entry<String, String>>>(hostsToCertificates.size());
        for (final Entry<String, String> entry : hostsToCertificates.entrySet()) {
            final Callable<Entry<String, String>> task = new Callable<Entry<String, String>>() {
                @Override
                public Entry<String, String> call() throws Exception {
                    final Entry<String, String> lookup = GeoIpLookupService.httpLookup("7.7.7.7", 
                            new ResponseHandler<Entry<String, String>>() {

                        @Override
                        public Entry<String, String> onResponse(final HttpResponse response)
                                throws Exception {
                            // This will be the JSON response from the geo-ip
                            // server
                            //final String body = IOUtils.toString(response.getEntity().getContent());
                            synchronized (TESTED_AND_VERIFIED_HOSTS) {
                                final String host = entry.getKey();
                                LOG.info("Adding tested and verified host: {}", host);
                                TESTED_AND_VERIFIED_HOSTS.add(host);
                            }
                            return entry;
                        }

                        @Override
                        public Entry<String, String> onException(Exception e) {
                            throw new RuntimeException("Could not load", e);
                        }
                        
                    }, entry.getKey());
                    
                    return lookup;

                }
            };
            tasks.add(task);
        }
        try {
            final Entry<String, String> response = 
                    pool.invokeAny(tasks, 60, TimeUnit.SECONDS);
            LOG.info("Using masquerade host: {}", response.getKey());
            return response;
        } catch (InterruptedException e) {
            LOG.error("Interrupted determining masquerade?", e);
        } catch (ExecutionException e) {
            LOG.error("Error determining masquerade?", e);
        } catch (TimeoutException e) {
            LOG.error("Loading masquerade site timed out?", e);
        }
        
        // If we can't get a verified response, just use whatever iterates
        // first.
        return hostsToCertificates.entrySet().iterator().next();
    }

    @JsonIgnore
    public String getMasqueradeHost() {
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
