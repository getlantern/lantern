package org.lantern.state;

import static org.junit.Assert.assertEquals;

import java.io.File;

import org.apache.commons.lang.SystemUtils;
import org.junit.BeforeClass;
import org.junit.Test;
import org.lantern.DefaultXmppHandler;
import org.lantern.EncryptedFileService;
import org.lantern.LanternModule;
import org.lantern.LanternUtils;
import org.lantern.privacy.LocalCipherProvider;
import org.lantern.state.Model.Run;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.inject.Guice;
import com.google.inject.Injector;

public class ModelIoTest {

    private static Logger LOG = LoggerFactory.getLogger(ModelIoTest.class);

    private static LocalCipherProvider localCipherProvider;
    private static EncryptedFileService encryptedFileService;

    
    @BeforeClass
    public static void setup() throws Exception {
        final Injector injector = Guice.createInjector(new LanternModule());
        
        injector.getInstance(DefaultXmppHandler.class);
        localCipherProvider = injector.getInstance(LocalCipherProvider.class);
        encryptedFileService = injector.getInstance(EncryptedFileService.class);
    }
    
    @Test
    public void testModelIo() throws Exception {
        final File testFile = new File("modelTest");
        testFile.delete();
        testFile.deleteOnExit();

        
        ModelIo io = new ModelIo(testFile, encryptedFileService, localCipherProvider);
        
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
        
        io = new ModelIo(testFile, encryptedFileService, localCipherProvider);
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
