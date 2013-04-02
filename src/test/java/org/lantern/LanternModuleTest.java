package org.lantern;

import static org.junit.Assert.*;

import org.junit.Test;
import org.lantern.http.JettyLauncher;
import org.lantern.privacy.DefaultLocalCipherProvider;
import org.lantern.privacy.UnencryptedFileService;
import org.lantern.state.Model;
import org.lastbamboo.common.portmapping.NatPmpService;
import org.lastbamboo.common.portmapping.PortMapListener;
import org.lastbamboo.common.portmapping.PortMappingProtocol;
import org.lastbamboo.common.portmapping.UpnpService;

import com.google.inject.Guice;
import com.google.inject.Injector;

public class LanternModuleTest {

    @Test
    public void test() {
        final LanternModule lm = new LanternModule();
        lm.setLocalCipherProvider(new DefaultLocalCipherProvider());
        lm.setEncryptedFileService(new UnencryptedFileService());
        lm.setUpnpService(new UpnpService() {
            @Override
            public void shutdown() {}
            
            @Override
            public void removeUpnpMapping(int mappingIndex) {}
            
            @Override
            public int addUpnpMapping(PortMappingProtocol protocol, int localPort,
                    int externalPortRequested, PortMapListener portMapListener) {
                return 0;
            }
        });
        lm.setNatPmpService(new NatPmpService() {
            
            @Override
            public void shutdown() {}
            
            @Override
            public void removeNatPmpMapping(int mappingIndex) {}
            
            @Override
            public int addNatPmpMapping(PortMappingProtocol protocol, int localPort,
                    int externalPortRequested, PortMapListener portMapListener) {
                return 0;
            }
        });
        final Injector injector = Guice.createInjector(lm);
        
        final LanternService xmpp = 
            injector.getInstance(DefaultXmppHandler.class);
        
        final Model model = injector.getInstance(Model.class);
        assertNotNull(xmpp);
        assertNotNull(model);
        assertTrue(model == injector.getInstance(Model.class));
        
        
        final LanternService jetty = 
                injector.getInstance(JettyLauncher.class);
        assertNotNull(jetty);
    }

}
