package org.lantern.util;

import org.apache.http.client.HttpClient;

/**
 * Interface for HTTP client factories.
 */
public interface HttpClientFactory {

    HttpClient newClient();

    HttpClient newDirectClient();

    HttpClient newProxiedClient();

}
