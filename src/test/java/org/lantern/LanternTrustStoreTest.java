package org.lantern;

import static org.junit.Assert.*;

import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.scheme.Scheme;
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
    public void testFallback() throws Exception {
      //System.setProperty("javax.net.debug", "ssl");
        final LanternKeyStoreManager ksm = TestingUtils.newKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final LanternSocketsUtil socketsUtil =
            new LanternSocketsUtil(null, trustStore);

        // Higher bit cipher suites aren't enabled on littleproxy.
        Launcher.configureCipherSuites();
        //trustStore.listEntries();
        final SSLSocketFactory socketFactory = socketsUtil.newTlsSocketFactoryJavaCipherSuites();
        
        final SSLSocket sock = (SSLSocket) socketFactory.createSocket();
        sock.connect(new InetSocketAddress("54.254.96.14", 16589), 20000);
        assertTrue(sock.isConnected());
        
        final OutputStream os = sock.getOutputStream();
        os.write("GET http://www.google.com HTTP/1.1\r\nHost: www.google.com\r\n\r\n".getBytes());
        os.flush();
        
        final InputStream is = sock.getInputStream();
        final byte[] bytes = new byte[30];
        is.read(bytes);
        
        final String response = new String(bytes);
        assertTrue(response.startsWith("HTTP/1.1 200 OK"));
        System.out.println(new String(bytes));
        os.close();
        is.close();
    }
    
    @Test
    public void testSites() throws Exception {//throws Exception {
        //System.setProperty("javax.net.debug", "ssl");
        //log.debug("CONFIGURED TRUSTSTORE: "+
        //        System.getProperty("javax.net.ssl.trustStore"));
        final LanternKeyStoreManager ksm = TestingUtils.newKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final LanternSocketsUtil socketsUtil =
            new LanternSocketsUtil(null, trustStore);

        //System.setProperty("javax.net.ssl.trustStore",
          //      trustStore.TRUSTSTORE_FILE.getAbsolutePath());

        //trustStore.listEntries();
        
        final HttpHost proxy = new HttpHost("54.254.96.14", 16589, "https");
        final org.apache.http.conn.ssl.SSLSocketFactory socketFactory =
            new org.apache.http.conn.ssl.SSLSocketFactory(
                socketsUtil.newTlsSocketFactoryJavaCipherSuites(),
                new LanternHostNameVerifier(proxy));
        //log.debug("CONFIGURED TRUSTSTORE: "+
          //      System.getProperty("javax.net.ssl.trustStore"));
        final Scheme sch = new Scheme("https", 443, socketFactory);

        final HttpClient client = new DefaultHttpClient();
        client.getConnectionManager().getSchemeRegistry().register(sch);
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 20000);
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 30000);

        final String[] success = {"talk.google.com",
            "lanternctrl.appspot.com", "docs.google.com",  "www.googleapis.com"}; //"www.exceptional.io",


        for (final String uri : success) {
            try {
                log.debug("Trying site: {}", uri);
                final String body = trySite(client, uri);
                log.debug("SUCCESS BODY FOR '{}': {}", uri, body.substring(0,Math.min(50, body.length())));
            } catch (Exception e) {
                log.error("Stack:\n"+ThreadUtils.dumpStack(e));
                fail("Unexpected exception on "+uri+"!\n"+ThreadUtils.dumpStack(e)+
                    "\n\nFAILED ON: "+uri);
            }
        }

        // URIs that should fail (signing certs we don't trust). Note this would
        // succeed (with the test failing as a result) with the normal root CAs,
        // which trust more signing certs than ours, such as verisign. We
        // just try to minimize the attack surface as much aLs possible.
        final String[] failure = {"chase.com"};
        for (final String uri : failure) {
            try {
                final String body = trySite(client, uri);
                log.debug("FAILURE BODY: "+body.substring(0,50));
                fail("Should not have succeeded on: "+uri);
            } catch (Exception e) {
                log.debug("Got expected exception "+e.getMessage());
            }
        }

        // Now we want to *modify the trust store at runtime* and make sure
        // those changes take effect.
        // THIS IS EXTREMELY IMPORTANT AS LANTERN RELIES ON THIS FOR ALL
        // P2P CONNECTIONS!!
        trustStore.deleteCert("equifaxsecureca");
        trustStore.deleteCert("equifaxsecureca2");

        final String[] noLongerSuccess = {"talk.google.com"};

        for (final String uri : noLongerSuccess) {
            try {
                final String body = trySite(client, uri);
                log.debug("SUCCESS BODY: "+body.substring(0, 50));
                fail("Should not have succeeded on: "+uri);
            } catch (Exception e) {
                // Expected since we should no longer trust talk.google.com
            }
        }
        // We need to add this back as otherwise it can affect other tests!
        trustStore.addCert(new URI("equifaxsecureca"), LanternUtils
                .certFromBytes(FileUtils.readFileToByteArray(new File(
                        "certs/equifaxsecureca.cer"))));
    }

    private String trySite(final HttpClient client, final String uri)
        throws Exception {
        final HttpGet get = new HttpGet();
        final String fullUri = "https://"+uri;
        log.info("Hitting URI: {}", fullUri);
        get.setURI(new URI(fullUri));

        final HttpResponse response = client.execute(get);
        final int code = response.getStatusLine().getStatusCode();
        final HttpEntity entity = response.getEntity();
        final String body =
            IOUtils.toString(entity.getContent()).toLowerCase();
        EntityUtils.consume(entity);

        if (code < 200 || code > 299) {
            // We use this method both for calls that should succeed and
            // calls that should fail, so this is expected.
            log.debug("Non-200 response code: "+code+" for "+uri+
                " with body:\n"+body);
        }
        get.reset();
        return body;
    }
}
