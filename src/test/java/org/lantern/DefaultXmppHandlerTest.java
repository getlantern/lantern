package org.lantern;

import static org.junit.Assert.assertTrue;

import java.util.Collection;
import java.util.HashSet;

import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for the XMPP handler.
 */
public class DefaultXmppHandlerTest {

    private static Logger LOG = 
        LoggerFactory.getLogger(DefaultXmppHandlerTest.class);
    
    /**
     * Make sure we're getting messages back from the controller.
     * 
     * @throws Exception If anything goes wrong.
     */
    @Test public void testControllerMessages() throws Exception {
        final String email = TestUtils.loadTestEmail();
        final String pwd = TestUtils.loadTestPassword();
        
        LanternHub.resetSettings(true);
        final Settings settings = LanternHub.settings();
        settings.setGetMode(true);
        settings.setProxies(new HashSet<String>());
        final XmppHandler handler = new DefaultXmppHandler();
        
        handler.connect(email, pwd);
        
        Collection<String> proxies = new HashSet<String>();
        
        int count = 0;
        while (proxies.isEmpty() && count < 100) {
            proxies = settings.getProxies();
            if (!proxies.isEmpty()) break;
            Thread.sleep(200);
            count++;
        }
        
        assertTrue(!proxies.isEmpty());
    }
}
