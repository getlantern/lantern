package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;
import io.netty.handler.codec.http.HttpHeaders;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.Callable;
import java.util.zip.GZIPOutputStream;

import org.apache.commons.io.IOUtils;
import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.StatusLine;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpHead;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.ByteArrayEntity;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.lantern.util.DefaultHttpClientFactory;
import org.lantern.util.HttpClientFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class HttpClientFactoryTest {

    private Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void testFallbackProxyConnection() throws Exception {
        //System.setProperty("javax.net.debug", "all");
        //System.setProperty("javax.net.debug", "ssl");
        
        TestingUtils.doWithGetModeProxy(new Callable<Void>() {
           @Override
            public Void call() throws Exception {
               final HttpClientFactory factory = 
                       new DefaultHttpClientFactory(new AllCensored());
               
               // Because we are censored, this should use the local proxy
               final HttpClient httpClient = factory.newClient();
               TestingUtils.assertIsUsingGetModeProxy(httpClient);
               
               httpClient.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 10000);
               httpClient.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 8000);

               final HttpHead head = new HttpHead("https://www.google.com");
               
               log.debug("About to execute get!");
               final HttpResponse response = httpClient.execute(head);
               final StatusLine line = response.getStatusLine();
               final int code = line.getStatusCode();
               if (code < 200 || code > 299) {
                   //log.error("Head request failed?\n"+line);
                   fail("Could not proxy");
               }
               head.reset();
                return null;
            } 
        });
    }
    
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
        final HttpClientFactory factory = new DefaultHttpClientFactory(new AllCensored());
        final HttpClient client = factory.newClient();
        TestingUtils.assertIsUsingGetModeProxy(client);

        TestingUtils.doWithGetModeProxy(new Callable<Void>() {
           @Override
            public Void call() throws Exception {
                testExceptional(client);
                testStats(client);
                return null;
            } 
        });
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
