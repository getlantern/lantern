package org.lantern.state;

import static org.junit.Assert.*;

import java.io.File;

import org.apache.commons.lang.SystemUtils;
import org.junit.Test;
import org.lantern.LanternUtils;
import org.lantern.state.Model.Run;

public class ModelIoTest {

    @Test
    public void testModelIo() throws Exception {
        final File testFile = new File("modelTest");
        testFile.delete();
        testFile.deleteOnExit();
        ModelIo io = new ModelIo(testFile);
        Model model = io.getModel();
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
        
        System.err.println(LanternUtils.jsonify(model));
        System.err.println(LanternUtils.jsonify(model,Run.class));
        
        io.write();
        
        io = new ModelIo(testFile);
        model = io.getModel();
        system = model.getSystem();
        settings = model.getSettings();
        connectivity = model.getConnectivity();
        assertEquals(10, model.getNinvites());
        assertEquals(false, settings.isAutoStart());
        
        // The user's IP address should not persist to disk
        assertEquals("", connectivity.getIp());
        
    }

}
