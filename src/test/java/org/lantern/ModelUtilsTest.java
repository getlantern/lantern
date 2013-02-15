package org.lantern;

import static org.junit.Assert.*;

import java.io.IOException;
import java.util.Collection;

import org.junit.Test;
import org.lantern.state.ModelUtils;
import org.lantern.util.LanternHttpClient;
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
        
        System.setProperty("javax.net.debug", "ssl");
        final KeyStoreManager ksm = new LanternKeyStoreManager();
        final LanternTrustStore trustStore = new LanternTrustStore(null, ksm);
        final LanternSocketsUtil socketsUtil = 
            new LanternSocketsUtil(null, trustStore);
        final LanternHttpClient httpClient = 
            new LanternHttpClient(socketsUtil, new Censored() {
            
            @Override
            public boolean isExportRestricted(String string) throws IOException {
                return false;
            }
            @Override
            public boolean isCountryCodeCensored(String cc) {
                return false;
            }
            @Override
            public boolean isCensored(Country country) {
                return true;
            }
            @Override
            public boolean isCensored() {
                return true;
            }
            @Override
            public boolean isCensored(String string) throws IOException {
                return true;
            }
            @Override
            public Collection<String> getCensored() {
                return null;
            }
            @Override
            public String countryCode() throws IOException {
                return null;
            }
            @Override
            public Country country() throws IOException {
                return null;
            }
        });
        final ModelUtils modelUtils = new ModelUtils(null, httpClient);
        final GeoData data = modelUtils.getGeoData("86.170.128.133");
        assertTrue(data.getLatitude() > 50.0);
        assertTrue(data.getLongitude() < 3.0);
        assertEquals("GB", data.getCountrycode());
        
        System.setProperty("javax.net.debug", "");
    }

}
