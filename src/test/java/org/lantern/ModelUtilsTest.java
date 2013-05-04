package org.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.lantern.state.DefaultModelUtils;
import org.lantern.util.HttpClientFactory;
import org.littleshoot.proxy.KeyStoreManager;

public class ModelUtilsTest {

    @Test
    public void testGeoData() throws Exception {
        /*
        new LanternTrustStore(new CertTracker() {
            @Override
            public String getCertForJid(String fullJid) {return null;}
            @Override
            public void addCert(String base64Cert, String fullJid) {}
        }, new LanternKeyStoreManager());
        */
        
        //System.setProperty("javax.net.debug", "ssl");
        final KeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(ksm);
        final LanternSocketsUtil socketsUtil = 
            new LanternSocketsUtil(null, trustStore);
        final HttpClientFactory httpClient =
            new HttpClientFactory(socketsUtil, new TestCensored());
        final DefaultModelUtils modelUtils = new DefaultModelUtils(null, httpClient);
        final GeoData data = modelUtils.getGeoData("86.170.128.133");
        assertTrue(data.getLatitude() > 50.0);
        assertTrue(data.getLongitude() < 3.0);
        assertEquals("GB", data.getCountrycode());
        
        final GeoData data2 = modelUtils.getGeoData("87.170.128.133");
        assertTrue(data2.getLatitude() > 50.0);
        assertTrue(data2.getLongitude() > 13.0);
        assertEquals("DE", data2.getCountrycode());
        
        System.setProperty("javax.net.debug", "");
    }

}
