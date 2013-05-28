package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;
import static org.mockito.Matchers.any;
import static org.mockito.Matchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.when;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.zip.GZIPOutputStream;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.StatusLine;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.ByteArrayEntity;
import org.apache.http.util.EntityUtils;
import org.jboss.netty.handler.codec.http.HttpHeaders;
import org.junit.Test;
import org.lantern.util.HttpClientFactory;
import org.littleshoot.proxy.KeyStoreManager;
import org.mockito.invocation.InvocationOnMock;
import org.mockito.stubbing.Answer;

public class HttpClientFactoryTest {

    /**
     * We've seen issues with HttpClient redirects from HTTPS sites to HTTP
     * sites. In practice though it shouldn't really affect us because none
     * of the HTTPS sites we hit should do that, nor should we allow it.
     * We just make sure to test all the sites we use to ensure this doesn't
     * happen.
     *
     * docs.google.com (feedback form)
     * exceptional.io -- error reporting
     * www.googleapis.com
     * lanternctrl.appspot.com (stats)
     *
     * @throws Exception If any unexpected errors occur.
     */
    @Test
    public void testAllInternallyProxiedSites() throws Exception {
        final File temp = new File(String.valueOf(RandomUtils.nextInt()));
        temp.deleteOnExit();
        final KeyStoreManager ksm = new LanternKeyStoreManager(temp);
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final LanternSocketsUtil socketsUtil =
            new LanternSocketsUtil(null, trustStore);
        
        //final LanternHttpClient client = TestUtils.getHttpClient();
        //client.setForceCensored(true);
        final Censored censored = new DefaultCensored();
        final HttpClientFactory factory = 
                new HttpClientFactory(socketsUtil, censored);
        final HttpClient client = factory.newProxiedClient();

        testExceptional(client);
        testGoogleDocs(factory);
        testStats(client);
    }

    private void testStats(final HttpClient client) throws Exception {
        final String uri = "https://lanternctrl.appspot.com/stats";

        final HttpGet get = new HttpGet(uri);
        final HttpResponse response = client.execute(get);
        final StatusLine line = response.getStatusLine();
        final int code = line.getStatusCode();
        get.reset();
        assertEquals(200, code);
    }

    private void testGoogleDocs(final HttpClientFactory clientFactory) 
        throws Exception {
        final LanternFeedback feedback = spy(new LanternFeedback(clientFactory));
        when(feedback.getHttpPost(anyString())).thenAnswer(new Answer<HttpPost>() {
            @Override
            public HttpPost answer(InvocationOnMock invocation) {
                HttpPost mockPost = spy(new HttpPost(LanternFeedback.HOST));
                doNothing().when(mockPost).setEntity((HttpEntity)any());
                return mockPost;
            }
        });
        final int responseCode =
            feedback.submit("Testing", "lanternftw@gmail.com");
        assertEquals(200, responseCode);
    }

    private void testExceptional(final HttpClient client)
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
