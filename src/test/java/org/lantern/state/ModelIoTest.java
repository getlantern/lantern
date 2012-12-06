package org.lantern.state;

import static org.junit.Assert.assertEquals;

import java.io.File;

import org.apache.commons.lang.SystemUtils;
import org.junit.BeforeClass;
import org.junit.Test;
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
        ModelIo io = 
            new ModelIo(testFile, TestUtils.getEncryptedFileService(), 
                    TestUtils.getLocalCipherProvider());
        
        Model model = io.get();
        SystemData system = model.getSystem();
        Settings settings = model.getSettings();
        Connectivity connectivity = model.getConnectivity();
        assertEquals("", connectivity.getIp());
        
        final String ip = "30.2.2.2";
        //connectivity.setIp(ip);
        
        assertEquals(0, model.getNinvites());
        model.setNinvites(10);
        assertEquals(10, model.getNinvites());
        
        assertEquals(true, settings.isAutoStart());
        settings.setAutoStart(false);
        
        if ("en".equalsIgnoreCase(SystemUtils.USER_LANGUAGE)) {
            assertEquals("en", system.getLang());
        }
        io.write();
        
        io = new ModelIo(testFile, TestUtils.getEncryptedFileService(), 
                TestUtils.getLocalCipherProvider());
        model = io.get();
        system = model.getSystem();
        settings = model.getSettings();
        connectivity = model.getConnectivity();
        assertEquals(false, settings.isAutoStart());
        assertEquals(10, model.getNinvites());
        
        // The user's IP address should not persist to disk
        assertEquals("", connectivity.getIp());
        
    }

}
