package org.lantern;

import static org.junit.Assert.assertTrue;

import java.util.HashSet;

import org.junit.Test;
import org.lantern.state.Model;
import org.lantern.state.Settings.Mode;
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
    @Test 
    public void testControllerMessages() throws Exception {
        TestUtils.load(true);
        final Model model = TestUtils.getModel();
        final org.lantern.state.Settings settings = model.getSettings();
        settings.setProxies(new HashSet<String>());
        
        settings.setMode(Mode.get);
        
        final XmppHandler handler = TestUtils.getXmppHandler();
        final ProxyTracker proxyTracker = TestUtils.getProxyTracker();
        proxyTracker.clear();
        handler.connect();
        
        LOG.debug("Checking for proxies in settings: {}", settings);
        int count = 0;
        while (proxyTracker.isEmpty() && count < 200) {
            if (!proxyTracker.isEmpty()) break;
            Thread.sleep(200);
            count++;
        }
        
        assertTrue("Should have received proxies from the controller", 
            !proxyTracker.isEmpty());
        TestUtils.close();
    }
}
