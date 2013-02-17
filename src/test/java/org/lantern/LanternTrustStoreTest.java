package org.lantern;

import static org.junit.Assert.fail;

import java.io.File;
import java.net.URI;

import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.scheme.Scheme;
import org.apache.http.conn.ssl.SSLSocketFactory;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.params.CoreConnectionPNames;
import org.apache.http.util.EntityUtils;
import org.junit.Test;
import org.junit.experimental.categories.Category;
import org.lantern.TestCategories.TrustStoreTests;
import org.lantern.util.LanternHostNameVerifier;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Category(TrustStoreTests.class)
public class LanternTrustStoreTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    @Test
    public void testSites() {//throws Exception {
        //System.setProperty("javax.net.debug", "ssl");
        log.debug("CONFIGURED TRUSTSTORE: "+System.getProperty("javax.net.ssl.trustStore"));
        //System.setProperty("javax.net.debug", "ssl");
        //final KeyStoreManager ksm = new LanternKeyStoreManager();
        //final LanternTrustStore trustStore = new LanternTrustStore(null, ksm);
        //final LanternSocketsUtil socketsUtil = 
            //new LanternSocketsUtil(null, trustStore);
        //final LanternTrustStore trustStore = TestUtils.getTrustStore();
        //final LanternSocketsUtil socketsUtil = TestUtils.getSocketsUtil();
        //final SSLSocketFactory socketFactory = 
            //new SSLSocketFactory(socketsUtil.newTlsSocketFactory(), 
              //  new LanternHostNameVerifier());
        
        final LanternTrustStore trustStore = TestUtils.getTrustStore();
        
        trustStore.listEntries();
        final LanternSocketsUtil socketsUtil = TestUtils.getSocketsUtil();
        final SSLSocketFactory socketFactory = 
            new SSLSocketFactory(socketsUtil.newTlsSocketFactoryJavaCipherSuites(), 
                new LanternHostNameVerifier());
        log.debug("CONFIGURED TRUSTSTORE: "+System.getProperty("javax.net.ssl.trustStore"));
        //final SSLSocketFactory socketFactory = LanternSocketsUtil.
        final Scheme sch = new Scheme("https", 443, socketFactory);

        final HttpClient client = new DefaultHttpClient();
        client.getConnectionManager().getSchemeRegistry().register(sch);
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 20000);
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 30000);

        final String[] success = {"talk.google.com", 
            "lanternctrl.appspot.com", "docs.google.com",  "www.googleapis.com", //"www.exceptional.io",
            "query.yahooapis.com", 
            LanternConstants.FALLBACK_SERVER_HOST+":"+
            LanternConstants.FALLBACK_SERVER_PORT};
        
        // URIs that should fail (signing certs we don't trust). Note this would
        // succeed (with the test failing as a result) with the normal root CAs,
        // which trust more signing certs than ours, such as verisign. We
        // just try to minimize the attack surface as much aLs possible.
        final String[] failure = {"chase.com"};
        for (final String uri : success) {
            System.err.println("Trying: "+uri);
            try {
                final String body = trySite(client, uri);
                log.debug("SUCCESS BODY: "+body);
            } catch (Exception e) {
                log.error("Stack:\n"+ThreadUtils.dumpStack(e));
                fail("Unexpected exception on "+uri+"!\n"+ThreadUtils.dumpStack(e)+
                    "\n\nFAILED ON: "+uri);
            }
        }
        for (final String uri : failure) {
            try {
                final String body = trySite(client, uri);
                log.debug("FAILURE BODY: "+body);
                fail("Should not have succeeded on: "+uri);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        
        // Now we want to *modify the trust store at runtime* and make sure
        // those changes take effect.
        // THIS IS EXTREMELY IMPORTANT AS LANTERN RELIES ON THIS FOR ALL
        // P2P CONNECTIONS!!
        trustStore.deleteCert("equifaxsecureca");
        
        final String[] noLongerSuccess = {"talk.google.com"};
        
        for (final String uri : noLongerSuccess) {
            try {
                final String body = trySite(client, uri);
                log.debug("SUCCESS BODY: "+body);
                fail("Should not have succeeded on: "+uri);
            } catch (Exception e) {
                // Expected since we should no longer trust talk.google.com
            }
        }
        // We need to add this back as otherwise it can affect other tests!
        trustStore.addCert("equifaxsecureca", new File("certs/equifaxsecureca.cer"));
        //TestUtils.close();
    }

    private String trySite(final HttpClient client, final String uri) 
        throws Exception {
        final HttpGet get = new HttpGet();
        get.setURI(new URI("https://"+uri));
        
        final HttpResponse response = client.execute(get);
        final int code = response.getStatusLine().getStatusCode();
        final HttpEntity entity = response.getEntity();
        final String body = 
            IOUtils.toString(entity.getContent()).toLowerCase();
        EntityUtils.consume(entity);

        if (code < 200 || code > 299) {
            log.warn("Unexpected response code: "+code+" for "+uri+
                " with body:\n"+body);
        }
        get.reset();
        return body;
    }
}
