package org.lantern.state;

import static org.junit.Assert.*;
import static org.mockito.Mockito.mock;

import java.io.File;

import org.apache.commons.lang.SystemUtils;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.CountryService;
import org.lantern.TestUtils;
import org.lantern.TestingUtils;
import org.lantern.privacy.LocalCipherProvider;

import com.google.common.io.Files;

public class ModelIoTest {

    private static File testFile;

    @BeforeClass
    public static void setup() throws Exception {
        testFile = new File(Files.createTempDir(), "modelTest");
        testFile.delete();
        testFile.deleteOnExit();
    }
    
    @Test
    public void testModelIo() throws Exception {
        final File dir = testFile.getParentFile();
        if (!dir.exists()) {
            assertTrue("Could not make temp directory!", dir.mkdirs());
        }
        assertTrue("Can't write to test directory!", dir.canWrite());
        CountryService countryService = TestUtils.getCountryService();
        ModelIo io = new ModelIo(testFile, TestUtils.getEncryptedFileService(),
                countryService, TestingUtils.newCommandLine(), 
                mock(LocalCipherProvider.class));

        Model model = io.get();

        final String id = model.getNodeId();
        SystemData system = model.getSystem();
        Connectivity connectivity = model.getConnectivity();
        assertEquals("", connectivity.getIp());

        if ("en".equalsIgnoreCase(SystemUtils.USER_LANGUAGE)) {
            assertEquals("en", system.getLang());
        }
        
        final String testId = "test-client-id";
        final Settings set = model.getSettings();
        final String existingId = set.getClientID();
        assertNotEquals("IDs should not be equal", testId, existingId);
        set.setClientID(testId);
        io.write();

        io = new ModelIo(testFile, TestUtils.getEncryptedFileService(),
                countryService, TestingUtils.newCommandLine(),
                mock(LocalCipherProvider.class));
        final Model model2 = io.get();
        system = model2.getSystem();
        connectivity = model2.getConnectivity();
        final String tok = model2.getSettings().getClientID();
        assertEquals(testId, tok);

        // The user's IP address should not persist to disk
        assertEquals("", connectivity.getIp());

        assertEquals("ID should persist across sessions",
            id, model.getNodeId());

    }

}
