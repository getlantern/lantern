package org.lantern.monitoring;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.ByteArrayEntity;
import org.apache.http.entity.ContentType;
import org.lantern.JsonUtils;
import org.lantern.LanternConstants;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;

/**
 * API for submitting stats to StatsHub.
 */
@Singleton
public class StatshubAPI {
    private static final Logger LOGGER = LoggerFactory
            .getLogger(StatshubAPI.class);

    private HttpClientFactory clientFactory;

    @Inject
    public StatshubAPI(HttpClientFactory clientFactory) {
        super();
        this.clientFactory = clientFactory;
    }

    /**
     * Submits stats to statshub.
     * 
     * @param counters
     * @param gauges
     * @return true if stats were successfully submitted
     */
    public boolean postStats(String instanceId, String countryCode, Stats stats) {
        Map<String, Object> request = new HashMap<String, Object>();
        request.put("countryCode", countryCode);
        request.put("counter", stats.getCounter());
        request.put("gauge", stats.getGauge());

        HttpClient client = clientFactory.newClient();
        HttpPost post = new HttpPost(urlFor(instanceId));
        byte[] requestJson = JsonUtils.toBytes(request);
        HttpEntity entity = new ByteArrayEntity(requestJson,
                ContentType.APPLICATION_JSON);
        post.setEntity(entity);
        try {
            HttpResponse resp = client.execute(post);
            if (!responseOk(resp)) {
                return false;
            }
            Map<String, Object> jsonResponse = JsonUtils.decode(resp
                    .getEntity().getContent(), Map.class);
            return Boolean.TRUE.equals(jsonResponse.get("success"));
        } catch (Exception e) {
            LOGGER.warn("Unable to submit stats: %s", e);
            return false;
        }
    }

    public StatsResponse getStats(String instanceId) {
        HttpClient client = clientFactory.newClient();
        HttpGet get = new HttpGet(urlFor(instanceId));
        try {
            HttpResponse resp = client.execute(get);
            if (!responseOk(resp)) {
                return null;
            }
            return JsonUtils.decode(resp.getEntity().getContent(),
                    StatsResponse.class);
        } catch (Exception e) {
            LOGGER.warn("Unable to get stats: %s", e);
            return null;
        }
    }

    private String urlFor(String instanceId) {
        return LanternConstants.statshubBaseAddress
                + instanceId;
    }

    private boolean responseOk(HttpResponse resp) throws IOException {
        int statusCode = resp.getStatusLine().getStatusCode();
        if (statusCode != 200) {
            LOGGER.warn("Got response status %s: %s",
                    statusCode,
                    IOUtils.toString(resp.getEntity().getContent()));
            return false;
        }
        return true;
    }
}
