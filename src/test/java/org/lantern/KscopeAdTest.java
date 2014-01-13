package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.File;

import org.apache.commons.io.FileUtils;
import org.junit.Test;
import org.lantern.kscope.LanternKscopeAdvertisement;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for kaleidoscope advertisement read/write/mapping
 */
public class KscopeAdTest {

    private static Logger LOG = 
        LoggerFactory.getLogger(KscopeAdTest.class);
    
    
    /**
     * Test Kscope ad JSON mapping to LanternKscopeAd
     * 
     * @throws Exception If anything goes wrong.
     */
    @Test 
    public void testKscopeAdParse() throws Exception {
        
        File jsonFile = FileUtils.toFile(
            Thread.currentThread().getContextClassLoader()
                .getResource("kscope_payload.json")
        );

        String jsonString = FileUtils.readFileToString(jsonFile);
        
        LanternKscopeAdvertisement ad = JsonUtils.OBJECT_MAPPER.readValue(
            jsonString, LanternKscopeAdvertisement.class
        );

        LOG.debug("Unserialized advertisement: {}", ad);
        assertTrue("Should have a valid kscope ad (see kscope_payload.json).",
            ad.getAddress().matches("127.0.0.1") && ad.getPort() == 12345 &&
            ad.getJid().matches("spiritjig@gmail.com/-lan-DEADBEEF") &&
            ad.getTtl() == 5
        );
    }

}
