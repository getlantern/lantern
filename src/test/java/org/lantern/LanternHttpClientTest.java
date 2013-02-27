package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.zip.GZIPOutputStream;

import org.apache.commons.io.IOUtils;
import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.StatusLine;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.ByteArrayEntity;
import org.apache.http.util.EntityUtils;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.junit.Test;
import org.lantern.state.ModelUtils;
import org.lantern.util.LanternHttpClient;

public class LanternHttpClientTest {

    /**
     * We've seen issues with HttpClient redirects from HTTPS sites to HTTP 
     * sites. In practice though it shouldn't really affect us because none
     * of the HTTPS sites we hit should do that, nor should we allow it.
     * We just make sure to test all the sites we use to ensure this doesn't
     * happen.
     * 
     * docs.google.com (feedback form)
     * exceptional.io -- error reporting
     * query.yahooapis.com (geo data lookup)
     * www.googleapis.com
     * lanternctrl.appspot.com (stats)
     * 
     * @throws Exception If any unexpected errors occur.
     */
    @Test
    public void testAllInternallyProxiedSites() throws Exception {
        final LanternHttpClient client = TestUtils.getHttpClient();
        client.setForceCensored(true);
        
        final ModelUtils modelUtils = TestUtils.getModelUtils();
        final GeoData data = modelUtils.getGeoData("86.170.128.133");
        assertTrue(data.getLatitude() > 50.0);
        assertTrue(data.getLongitude() < 3.0);
        assertEquals("GB", data.getCountrycode());
        
        testExceptional(client);
        testGoogleDocs(client);
        testStats(client);
    }
    
    private void testStats(final LanternHttpClient client) throws Exception {
        final String uri = "https://lanternctrl.appspot.com/stats";
        
        final HttpGet get = new HttpGet(uri);
        final HttpResponse response = client.execute(get);
        final StatusLine line = response.getStatusLine();
        final int code = line.getStatusCode();
        get.reset();
        assertEquals(200, code);
    }

    private void testGoogleDocs(final LanternHttpClient client) 
        throws Exception {
        final LanternFeedback feedback = new LanternFeedback(client, true);
        final int responseCode = 
            feedback.submit("Testing", "lanternftw@gmail.com");
        assertEquals(200, responseCode);
    }

    private void testExceptional(final LanternHttpClient client) 
        throws Exception {
        final String requestBody = "{request: {}}";
        final String url = "https://www.exceptional.io/api/errors?" +
             "api_key=77&protocol_version=6";
        final HttpPost post = new HttpPost(url);
        post.setHeader(HttpHeaders.Names.CONTENT_ENCODING, "gzip");
        final ByteArrayOutputStream baos = new ByteArrayOutputStream();
        GZIPOutputStream gos = null;
        InputStream is = null;
        gos = new GZIPOutputStream(baos);
        gos.write(requestBody.getBytes("UTF-8"));
        gos.close();
        post.setEntity(new ByteArrayEntity(baos.toByteArray()));
        System.err.println("Sending data to server...");
        final HttpResponse response = client.execute(post);
        System.err.println("Sent data to server...");

        final int statusCode = response.getStatusLine().getStatusCode();
        final HttpEntity responseEntity = response.getEntity();
        is = responseEntity.getContent();
        if (statusCode < 200 || statusCode > 299) {
            final String body = IOUtils.toString(is);
            InputStream bais = null;
            OutputStream fos = null;
            try {
                bais = new ByteArrayInputStream(body.getBytes());
                fos = new FileOutputStream(new File("bug_error.html"));
                IOUtils.copy(bais, fos);
            } finally {
                IOUtils.closeQuietly(bais);
                IOUtils.closeQuietly(fos);
            }
            final Header[] headers = response.getAllHeaders();
            for (int i = 0; i < headers.length; i++) {
                System.err.println(headers[i]);
            }
            fail("Error connecting to exceptional?");
        }

        // We always have to read the body.
        EntityUtils.consume(responseEntity);

        IOUtils.closeQuietly(is);
        IOUtils.closeQuietly(gos);
        post.reset();
    }
}
