package org.lantern;

import org.apache.commons.lang.SystemUtils;
import org.junit.Test;


public class ProxifierTest {

    @Test
    public void testOsxProxy() throws Exception {
        if (!SystemUtils.IS_OS_MAC_OSX) {
            return;
        }
        //Proxifier.proxyOsxViaScript();
        
        // Just make sure we don't get an exception
        new Proxifier(null).osxPrefPanesLocked();
    }
}
