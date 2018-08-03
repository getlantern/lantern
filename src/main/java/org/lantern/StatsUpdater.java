package org.lantern;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Map;

import org.apache.commons.beanutils.PropertyUtils;
import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.util.EntityUtils;
import org.lantern.event.Events;
import org.lantern.state.Model;
import org.lantern.state.SyncPath;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

@Singleton
public class StatsUpdater extends Thread {
    Logger log = LoggerFactory.getLogger(StatsUpdater.class);

    private final Model model;

    private static final long SLEEP_INTERVAL = 60 * 1000;

    private final HttpClientFactory httpClientFactory;

    @Inject
    public StatsUpdater(final Model model, 
            final HttpClientFactory httpClientFactory) {
        super();
        setDaemon(true);
        setName("Stats-Updating-Thread-"+hashCode());
        this.model = model;
        this.httpClientFactory = httpClientFactory;
    }

    @Override
    public void run() {
        // Wait for a bit because we may not have proxies at the very beginning
        // if we need them.
        try {
            sleep(4000);
        } catch (final InterruptedException e1) {
        }
        while (true) {
            updateStats();
            try {
                sleep(SLEEP_INTERVAL);
            } catch (InterruptedException e) {
                continue;
            }
        }
    }

    @SuppressWarnings("unchecked")
    private void updateStats() {
        log.debug("Updating stats...");
        
        final HttpClient client = this.httpClientFactory.newClient();
        final HttpGet get = new HttpGet();
        String json = "";
        try {
            final URI uri = new URI(LanternClientConstants.STATS_URL);
            get.setURI(uri);
            final HttpResponse response = client.execute(get);
            final HttpEntity entity = response.getEntity();
            json = IOUtils.toString(entity.getContent());
            EntityUtils.consume(entity);
            Map<String, Object> stats = JsonUtils.OBJECT_MAPPER.readValue(json, Map.class);
            Map<String, Object> global = (Map<String, Object>) stats.get("global");
            if (global == null) {
                log.info("Empty global stats");
                return;
            }
            updateModel(model.getGlobal(), global);
            Map<String, Object> countries = (Map<String, Object>) stats
                    .get("countries");
            for (Country country : model.getCountries().values()) {
                Object countryData = countries.get(country.getCode());
                if (countryData != null) {
                    updateModel(country, (Map<String, Object>) countryData);
                }
            }
            Events.sync(SyncPath.GLOBAL, model.getGlobal());
            Events.sync(SyncPath.COUNTRIES, model.getCountries());
        } catch (final IOException e) {
            log.info("Error getting stats from URL "+LanternClientConstants.STATS_URL+" RESPONSE:\n"+json, e);
        } catch (final URISyntaxException e) {
            log.error("URI error", e);
        } catch (IllegalAccessException e) {
            log.error("stats format error", e);
        } catch (InvocationTargetException e) {
            log.error("stats format error", e);
        } finally {
            get.reset();
        }
    }

    @SuppressWarnings("unchecked")
    private void updateModel(Object dest, Map<String, Object> src)
            throws IllegalAccessException, InvocationTargetException {
        Map<String, Object> map = src;
        try {
            for (Map.Entry<String, Object> entry : map.entrySet()) {
                Object value = entry.getValue(); // 5
                String key = entry.getKey(); // bps
                if (value instanceof Map) {
                    updateModel(PropertyUtils.getSimpleProperty(dest, key),
                            ((Map<String, Object>) value));
                } else {
                    PropertyUtils.setSimpleProperty(dest, key, value);
                }
            }
        } catch (NoSuchMethodException e) {
            // do nothing; lantern-controller collects more stats than lantern
            // uses
        }
    }

}
