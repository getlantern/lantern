package org.lantern.state;

import static org.junit.Assert.assertEquals;

import java.io.File;

import org.apache.commons.lang.SystemUtils;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.CountryService;
import org.lantern.TestUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ModelIoTest {

    private static Logger LOG = LoggerFactory.getLogger(ModelIoTest.class);

    private static File testFile;

    @BeforeClass
    public static void setup() throws Exception {
        testFile = new File("modelTest");
        testFile.delete();
        testFile.deleteOnExit();
    }
    
    @Test
    public void testModelIo() throws Exception {
        CountryService countryService = TestUtils.getCountryService();
        ModelIo io = new ModelIo(testFile, TestUtils.getEncryptedFileService(),
                null, countryService);

        Model model = io.get();
        
        final String id = model.getNodeId();
        SystemData system = model.getSystem();
        Connectivity connectivity = model.getConnectivity();
        assertEquals("", connectivity.getIp());

        assertEquals(-1, model.getNinvites());
        model.setNinvites(10);
        assertEquals(10, model.getNinvites());
        
        if ("en".equalsIgnoreCase(SystemUtils.USER_LANGUAGE)) {
            assertEquals("en", system.getLang());
        }
        io.write();

        io = new ModelIo(testFile, TestUtils.getEncryptedFileService(), null,
                countryService);
        model = io.get();
        system = model.getSystem();
        connectivity = model.getConnectivity();
        assertEquals(10, model.getNinvites());
        
        // The user's IP address should not persist to disk
        assertEquals("", connectivity.getIp());
        
        assertEquals("ID should persist across sessions", 
            id, model.getNodeId());
        
    }

}
