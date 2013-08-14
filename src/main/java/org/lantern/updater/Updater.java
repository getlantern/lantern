package org.lantern.updater;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.http.Header;
import org.apache.http.HttpResponse;
import org.apache.http.StatusLine;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpHead;
import org.apache.http.client.methods.HttpRequestBase;
import org.lantern.LanternClientConstants;
import org.lantern.event.Events;
import org.lantern.launcher.UpdateableLauncher;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.io.Files;
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

    private HttpResponse doRequest(URI updateURI, HttpRequestBase request) {
        HttpClient client = httpClientFactory.newClient();
        try {
            HttpResponse response = client.execute(request);
            return response;
        } catch (ClientProtocolException e) {
            error(e, updateURI);
            return null;
        } catch (IOException e) {
            error(e, updateURI);
            return null;
        }
    }

    public HttpResponse get(URI updateURI) {
        HttpGet request = new HttpGet(updateURI);

        return doRequest(updateURI, request);
    }

    public HttpResponse head(URI updateURI) {
        HttpHead request = new HttpHead(updateURI);

        return doRequest(updateURI, request);
    }

    /**
     * Download an update if necessary. If no update is necessary, does nothing.
     *
     * On success, posts an UpdateSucceededEvent. On failure, posts an
     * UpdateFailedEvent.
     *
     * This method is synchronized because starting multiple downloads
     * simultaneously would be bad.
     *
     * @param updateURI
     */
    public synchronized void update(URI updateURI) {
        //check if an update is necessary
        String localEtag = getLocalEtag();
        HttpResponse head = head(updateURI);
        if (head == null) {
            return;
        }
        Header[] headers = head.getHeaders("ETag");
        if (headers.length == 0) {
            //no etag headers -- something is wrong
            error("Missing etag header", updateURI);
        }
        String remoteEtag = null;
        for (Header header : headers) {
            remoteEtag = header.getValue();
            if (remoteEtag.equals(localEtag)) {
                //local copy is already up-to-date
                return;
            }
        }

        HttpResponse response = get(updateURI);
        if (response == null) {
            return;
        }
        StatusLine statusLine = response.getStatusLine();
        if (statusLine.getStatusCode() != 200) {
            error("Bad status: " + statusLine, updateURI);
            return;
        }
        try {
            InputStream content = response.getEntity().getContent();
            File dotLanternJar = new File(LanternClientConstants.CONFIG_DIR,
                    UpdateableLauncher.LANTERN_JAR_NAME);
            File newDotLanternJar = new File(dotLanternJar + ".new");
            OutputStream output = new FileOutputStream(newDotLanternJar);
            IOUtils.copy(content, output);
            IOUtils.closeQuietly(output);
            Files.move(newDotLanternJar, dotLanternJar);

            File dotLanternEtag = getEtagFile();
            FileUtils.write(dotLanternEtag, remoteEtag);

            UpdateSucceededEvent event = new UpdateSucceededEvent();
            Events.asyncEventBus().post(event);
        } catch (IllegalStateException e) {
            error(e, updateURI);
        } catch (IOException e) {
            error(e, updateURI);
        }
    }

    private String getLocalEtag() {
        File dotLanternEtag = getEtagFile();
        try {
            return FileUtils.readFileToString(dotLanternEtag);
        } catch (IOException e) {
            return "";
        }
    }

    private File getEtagFile() {
        return new File(LanternClientConstants.CONFIG_DIR,
                UpdateableLauncher.LANTERN_JAR_NAME + ".etag");
    }

    private void error(String reason, URI updateURI) {
        LOG.info("Error loading " + updateURI + ": " + reason);
        String message = "Failed to download update: " + reason;
        UpdateFailedEvent event = new UpdateFailedEvent(updateURI, message);
        Events.asyncEventBus().post(event);
    }

    private void error(Exception exception, URI updateURI) {
        LOG.info("Error loading " + updateURI, exception);
        String message = "Failed to download update: " + exception.getMessage();
        UpdateFailedEvent event = new UpdateFailedEvent(updateURI, message);
        Events.asyncEventBus().post(event);
    }
}
