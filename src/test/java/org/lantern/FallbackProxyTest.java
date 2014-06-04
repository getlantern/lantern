package org.lantern;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import java.io.File;
import java.security.KeyStoreException;
import java.security.cert.CertificateException;

import javax.net.ssl.SSLSocketFactory;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.SystemUtils;
import org.apache.commons.lang.math.RandomUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.HttpResponse;
import org.apache.http.StatusLine;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.conn.params.ConnRoutePNames;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;
import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.geoip.GeoIpLookupService;
import org.lantern.proxy.BaseChainedProxy;
import org.lantern.proxy.CertTrackingSslEngineSource;
import org.lantern.proxy.GiveModeProxy;
import org.lantern.simple.Get;
import org.lantern.state.Model;
import org.littleshoot.proxy.SslEngineSource;
import org.littleshoot.proxy.TransportProtocol;
import org.littleshoot.proxy.impl.NetworkUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Tests running a fallback proxy based on the current code base with a client
 * that hits that proxy.
 */
public class FallbackProxyTest {

    private Logger log = LoggerFactory.getLogger(getClass());
    private static final String GET_HOST = "127.0.0.1";
    private static final int GET_PORT = 8787;
    private static String GIVE_HOST;
    private static final int GIVE_PORT = LanternUtils.randomPort();
    private static final String PROXY_AUTH_TOKEN = "AUTHMEBABY!";

    private static String originalFallbackKeystorePath;
    
    // We have to make sure to clean up the keystore path to avoid affecting
    // other tests when tests are run together.
    @BeforeClass 
    public static void setUpClass() throws Exception {
        GIVE_HOST = NetworkUtils.getLocalHost().getHostAddress();
        originalFallbackKeystorePath = LanternUtils.getFallbackKeystorePath();
        // This is the keystore that's used on the server side -- a test 
        // dummy of littleproxy_keystore.jks that's used in production.
        LanternUtils.setFallbackKeystorePath("src/test/resources/test.jks");
    }

    @AfterClass 
    public static void tearDownClass() { 
        LanternUtils.setFallbackKeystorePath(originalFallbackKeystorePath);
        LanternUtils.setFallbackProxy(false);
    }

    @Test
    public void testFallback() throws Exception {
        //System.setProperty("javax.net.debug", "all");
        //System.setProperty("javax.net.debug", "ssl");
        final File temp = new File(SystemUtils.getJavaIoTmpDir(), 
                String.valueOf(RandomUtils.nextLong()));
        
        FileUtils.forceDeleteOnExit(temp);
        final LanternKeyStoreManager ksm = 
                new LanternKeyStoreManager(temp);
        ksm.start();
        
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);

        final String testId = "test@gmail.com/somejidresource";
        ksm.getBase64Cert(testId);
        
        // This adds the dummy test certificate to the trust store on the 
        // client side to ensure it will trust our test proxy.
        addTestCertToTrustStore(trustStore);

        // This runs a give mode proxy that's identical to the fallback servers
        // running in production except it uses a different keystore, so 
        // will send different keys to the client side (see comments above on 
        // using a test keystore).
        final GiveModeProxy give = startGiveModeProxy(trustStore, ksm);
        final Get get = startGetModeProxy();
        
        try {
            log.debug("Connecting on port: {}", GIVE_PORT);
            if (!LanternUtils.waitForServer(GIVE_HOST, GIVE_PORT, 4000)) {
                fail("Could not get server on expected port?");
            }
            if (!LanternUtils.waitForServer(GET_HOST, GET_PORT, 4000)) {
                fail("Could not get server on expected port?");
            }
            
            final LanternSocketsUtil util = new LanternSocketsUtil(trustStore);
            
            final DefaultHttpClient httpClient = new DefaultHttpClient();
            
            // We prefer this one because this way the client can advertise a more
            // typical set of suites, and the server can choose.
            final SSLSocketFactory clientFactory = util.newTlsSocketFactoryJavaCipherSuites();
            //final SSLSocketFactory client = util.newTlsSocketFactory(IceConfig.getCipherSuites());
            
            final HttpHost proxy = new HttpHost(GET_HOST, GET_PORT);
            httpClient.getParams().setParameter(ConnRoutePNames.DEFAULT_PROXY, proxy);
            hitSite(httpClient, "https://www.google.com");
            
            // Just make sure there's nothing that pops up with making a second
            // request.
            hitSite(httpClient, "https://www.wikipedia.org");
        } finally {
            try {
                get.stop();
            } catch (Exception e) {
                // ignore
            }
            try {
                give.stop();
            } catch (Exception e) {
                // ignore
            }
            ksm.stop();
        }
    }

    private final String LITTLEPROXY_TEST = 
        "-----BEGIN CERTIFICATE-----\n"
        +"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\n"
        +"-----END CERTIFICATE-----";
    
    private void addTestCertToTrustStore(final LanternTrustStore trustStore) 
            throws CertificateException, KeyStoreException {
        trustStore.addCert("littleproxy", LITTLEPROXY_TEST);
    }


    private void hitSite(DefaultHttpClient httpClient, final String url) 
            throws Exception {
        final HttpGet get = new HttpGet(url);
        get.addHeader(BaseChainedProxy.X_LANTERN_AUTH_TOKEN, PROXY_AUTH_TOKEN);
        
        try {
            log.debug("About to execute get!");
            final HttpResponse response = httpClient.execute(get);
            final StatusLine line = response.getStatusLine();
            log.debug("Got response status: {}", line);
            final HttpEntity entity = response.getEntity();
            final String body = IOUtils.toString(entity.getContent());
            EntityUtils.consume(entity);
            log.debug("GOT RESPONSE BODY FOR EMAIL:\n"+body);

            final int code = line.getStatusCode();
            if (code < 200 || code > 299) {
                log.error("OAuth error?\n"+line);
                fail("Could not get response?");
            }
        } finally {
            get.reset();
        }
    }

    private GiveModeProxy startGiveModeProxy(final LanternTrustStore trustStore, 
            final LanternKeyStoreManager keyStoreManager) {
        LanternUtils.setFallbackProxy(true);
        final Model model = new Model();
        model.getSettings().setServerPort(GIVE_PORT);
        model.getSettings().setProxyAuthToken(PROXY_AUTH_TOKEN);
        final SslEngineSource sslEngineSource = 
            new CertTrackingSslEngineSource(trustStore, keyStoreManager);
        PeerFactory peerFactory = mock(PeerFactory.class);
        final GiveModeProxy proxy = 
                new GiveModeProxy(model, sslEngineSource, peerFactory, new GeoIpLookupService(null));
        
        proxy.start();
        return proxy;
    }
    
    private Get startGetModeProxy() throws Exception {
        Get get = new Get(GET_PORT,
                GIVE_HOST + ":" + GIVE_PORT,
                PROXY_AUTH_TOKEN,
                TransportProtocol.TCP);
        get.start();
        return get;
    }
}
