package org.lantern;

import static org.junit.Assert.fail;

import java.io.IOException;
import java.net.URI;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LanternTrustManagerTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    @Test
    public void test() {
        final LanternClientSslContextFactory factory = 
            TestUtils.getClientSslContextFactory();
        final SSLSocketFactory socketFactory = 
            new SSLSocketFactory(factory.getClientContext(), 
                SSLSocketFactory.STRICT_HOSTNAME_VERIFIER);
        final Scheme sch = new Scheme("https", 443, socketFactory);
        final DefaultHttpClient client = new DefaultHttpClient();
        client.getConnectionManager().getSchemeRegistry().register(sch);
        
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 
            50000);
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
        
        // URIs that should succeed (signing certs we trust)
        final String[] success = {"talk.google.com", 
            "query.yahooapis.com"};
        
        // URIs that should fail (signing certs we don't trust)
        final String[] failure = {"chase.com"};
        for (final String uri : success) {
            try {
                final String body = trySite(client, uri);
                log.debug("SUCCESS BODY: "+body);
            } catch (Exception e) {
                fail("Unexpected exception!\n"+ThreadUtils.dumpStack());
            }
        }
        for (final String uri : failure) {
            try {
                final String body = trySite(client, uri);
                log.debug("FAILURE BODY: "+body);
                fail("Should not have succeeded!");
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    private String trySite(final DefaultHttpClient client, final String uri) 
        throws Exception {
        final HttpGet get = new HttpGet();
        get.setURI(new URI("https://"+uri));
        
        final HttpResponse response = client.execute(get);
        final int code = response.getStatusLine().getStatusCode();
        if (code < 200 || code > 299) {
            throw new IOException("Unexpected response code!!"+code);
        }
        final HttpEntity entity = response.getEntity();
        final String body = 
            IOUtils.toString(entity.getContent()).toLowerCase();
        EntityUtils.consume(entity);

        get.releaseConnection();
        return body;
    }

}
