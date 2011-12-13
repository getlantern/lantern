package org.lantern;

import static org.junit.Assert.assertTrue;

import org.junit.Test;


public class DefaultTrustedContactsManagerTest {

    @Test public void testLoadingContacts() throws Exception {
        final DefaultTrustedContactsManager tcm = 
            new DefaultTrustedContactsManager();
        tcm.addTrustedContact("test@test.com");
        
        
        final DefaultTrustedContactsManager tcm2 = 
            new DefaultTrustedContactsManager();
        assertTrue(tcm2.isTrusted("test@test.com"));
        
        tcm.removeTrustedContact("test@test.com");
        
        final DefaultTrustedContactsManager tcm3 = 
            new DefaultTrustedContactsManager();
        assertTrue(!tcm3.isTrusted("test@test.com"));
    }
    
}
