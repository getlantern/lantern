package org.lantern;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Map;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.codehaus.jackson.map.ObjectMapper;
import org.lantern.event.Events;
import org.lantern.event.SyncEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class StatsUpdater extends Thread {
    Logger log = LoggerFactory.getLogger(StatsUpdater.class);

    private static final long SLEEP_INTERVAL = 60 * 1000;

    public StatsUpdater() {
        super();
        setDaemon(true);
    }

    @Override
    public void run() {
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
        final HttpGet get = new HttpGet();
        try {
            final URI uri = new URI(LanternConstants.STATS_URL);
            final DefaultHttpClient client = new DefaultHttpClient();
            get.setURI(uri);
            final HttpResponse response = client.execute(get);
            final HttpEntity entity = response.getEntity();
            final String json =
                IOUtils.toString(entity.getContent());
            EntityUtils.consume(entity);
            final ObjectMapper om = new ObjectMapper();
            Map<String, Object> stats = om.readValue(json, Map.class);
            Events.asyncEventBus().post(new SyncEvent("global", stats.get("global")));
            Events.asyncEventBus().post(new SyncEvent("countries", stats.get("countries")));

        } catch (final IOException e) {
            log.warn("Could not connect to stats url", e);
        } catch (final URISyntaxException e) {
            log.error("URI error", e);
        } finally {
            get.releaseConnection();
        }
    }

}
