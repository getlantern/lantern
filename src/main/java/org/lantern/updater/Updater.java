package org.lantern.updater;

import java.io.IOException;
import java.net.URI;

import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.lantern.event.Events;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Inject;
import com.google.inject.Singleton;


/**
 * An updater takes the URL to an updated Lantern JAR file and downloads it into
 * the users's .lantern directory. Then it sends a LanternUpdatedEvent, so that
 * Lantern can restart if necessary.
 */
@Singleton
public class Updater {
    private static final Logger LOG = LoggerFactory.getLogger(Events.class);
    private final HttpClientFactory httpClientFactory;

    @Inject
    public Updater(final HttpClientFactory httpClientFactory) {
        this.httpClientFactory = httpClientFactory;
    }

    public void update(URI updateURI) {
        HttpClient client = httpClientFactory.newClient();
        HttpGet request = new HttpGet(updateURI);

        //FIXME: whom do we want to handle the errors here?
        //I guess we should log them and notify the user.
        try {
            client.execute(request);
        } catch (ClientProtocolException e) {
            error(e, updateURI);
        } catch (IOException e) {
            error(e, updateURI);
        }
    }

    private void error(IOException e, URI updateURI) {
        LOG.info("Error loading " + updateURI, e);
        Events.asyncEventBus().post(new UpdateFailedEvent("Failed to download update"));
    }
}
