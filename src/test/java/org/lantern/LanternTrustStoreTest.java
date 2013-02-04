package org.lantern;

import static org.junit.Assert.fail;

import java.net.URI;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;

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
import org.lantern.util.LanternHostNameVerifier;
import org.littleshoot.util.ThreadUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.barchart.udt.SocketUDT;

public class LanternTrustStoreTest {

    private final Logger log = LoggerFactory.getLogger(getClass());
    @Test
    public void test() {
        // The following takes care of configuring the trust store.
        new LanternTrustStore(
            new CertTracker() {
            
            @Override
            public String getCertForJid(String fullJid) {return null;}
            
            @Override
            public void addCert(String base64Cert, String fullJid) {}
        });
        
        /*
        System.setProperty("javax.net.ssl.trustStore", 
            "/Users/afisk/lantern/generated_lantern_truststore.jks");
        final LanternClientSslContextFactory factory = 
            TestUtils.getClientSslContextFactory();
        
        final SSLSocketFactory socketFactory = 
            new SSLSocketFactory(factory.getClientContext(), 
                SSLSocketFactory.STRICT_HOSTNAME_VERIFIER);
        final Scheme sch = new Scheme("https", 443, socketFactory);
        */
        
        //*/
        final SSLSocketFactory socketFactory;
        try {
            socketFactory = new SSLSocketFactory(SSLSocketFactory.TLS, null, 
                null, null, null, null, new LanternHostNameVerifier());
        } catch (KeyManagementException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
            return;
        } catch (UnrecoverableKeyException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
            return;
        } catch (NoSuchAlgorithmException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
            return;
        } catch (KeyStoreException e1) {
            // TODO Auto-generated catch block
            e1.printStackTrace();
            return;
        }
        
        //final SSLSocketFactory socketFactory = LanternSocketsUtil.
        final Scheme sch = new Scheme("https", 443, socketFactory);

        //new SSLSocketFactory(SSLSocketFactory.getSocketFactory(), new LanternHostNameVerifier());
        //SchemeRegistry registry = new SchemeRegistry();
        //registry.register(new Scheme("https", socketFactory, 443))
        final DefaultHttpClient client = new DefaultHttpClient();
        client.getConnectionManager().getSchemeRegistry().register(sch);
        
        client.getParams().setParameter(CoreConnectionPNames.CONNECTION_TIMEOUT, 
            50000);
        client.getParams().setParameter(CoreConnectionPNames.SO_TIMEOUT, 120000);
        
        //final String[] success = {"docs.google.com"};
        final String[] success = {"talk.google.com", "lanternctrl.appspot.com",
            "docs.google.com", "www.exceptional.io", "www.googleapis.com",
            "query.yahooapis.com", 
            LanternConstants.FALLBACK_SERVER_HOST+":"+
            LanternConstants.FALLBACK_SERVER_PORT};
        
        // URIs that should fail (signing certs we don't trust). Note this would
        // succeed (with the test failing as a result) with the normal root CAs,
        // which trust more signing certs than ours, such as verisign. We
        // just try to minimize the attack surface as much as possible.
        final String[] failure = {"chase.com"};
        for (final String uri : success) {
            try {
                final String body = trySite(client, uri);
                log.debug("SUCCESS BODY: "+body);
            } catch (Exception e) {
                log.error("Stack:\n"+ThreadUtils.dumpStack(e));
                fail("Unexpected exception!\n"+ThreadUtils.dumpStack(e)+
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
    }

    private String trySite(final DefaultHttpClient client, final String uri) 
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
        get.releaseConnection();
        return body;
    }

}
