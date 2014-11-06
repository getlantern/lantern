package org.lantern.proxy.pt;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Map;
import java.util.Map.Entry;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpResponse;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.util.HostSpoofedHTTPGet.ResponseHandler;
import org.lantern.util.Threads;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class FlashlightMasquerade {
    
    private final Logger LOG = LoggerFactory.getLogger(getClass());
    
    private static Map.Entry<String, String> cachedMasqueradeHost;

    private final Map<String, String> defaultHostsToCerts;

    private final MasqueradeListener masqueradeListener;

    public FlashlightMasquerade(final Map<String, String> defaultHostsToCerts,
            final MasqueradeListener masqueradeListener) {
        this.defaultHostsToCerts = defaultHostsToCerts;
        this.masqueradeListener = masqueradeListener;
    }

    public synchronized Entry<String, String> determineMasqueradeHost() {
        LOG.info("Determining masquerade host to use...");

        // Cache this across all masquerades to avoid doing lookups multiple
        // times.
        if (cachedMasqueradeHost != null) {
            return cachedMasqueradeHost;
        }
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
            new ArrayList<Callable<Entry<String, String>>>(defaultHostsToCerts.size());
        for (final Entry<String, String> entry : defaultHostsToCerts.entrySet()) {
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
                            final String host = entry.getKey();
                            final int code = response.getStatusLine().getStatusCode();
                            if (code < 200 || code > 299) {
                                LOG.warn("Got error for masquerade: {}", host);
                            } else {
                                masqueradeListener.onTestedAndVerifiedHost(host);
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
                    pool.invokeAny(tasks, 120, TimeUnit.SECONDS);
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
        return defaultHostsToCerts.entrySet().iterator().next();
    }
}
