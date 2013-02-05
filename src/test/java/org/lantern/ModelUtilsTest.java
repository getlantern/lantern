package org.lantern;

import static org.junit.Assert.*;

import org.junit.Test;
import org.lantern.state.ModelUtils;

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
        
        final ModelUtils modelUtils = TestUtils.getModelUtils();
        final GeoData data = modelUtils.getGeoData("86.170.128.133");
        assertTrue(data.getLatitude() > 50.0);
        assertTrue(data.getLongitude() < 3.0);
        assertEquals("gb", data.getCountrycode());
    }

}
