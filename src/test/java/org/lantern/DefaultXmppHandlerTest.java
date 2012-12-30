package org.lantern;

import static org.junit.Assert.assertTrue;

import java.util.Collection;
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
        //final String email = TestUtils.loadTestEmail();
        //final String pwd = TestUtils.loadTestPassword();
        
        //LanternHub.resetSettings(true);
        final Model model = TestUtils.getModel();
        final org.lantern.state.Settings settings = model.getSettings();
        //settings.setGetMode(true);
        settings.setProxies(new HashSet<String>());
        
        settings.setMode(Mode.get);
        
        final XmppHandler handler = TestUtils.getXmppHandler();
        handler.start();
        //handler.connect(email, pwd);
        handler.connect();
        
        Collection<String> proxies = new HashSet<String>();
        
        int count = 0;
        while (proxies.isEmpty() && count < 200) {
            proxies = settings.getProxies();
            if (!proxies.isEmpty()) break;
            Thread.sleep(200);
            count++;
        }
        
        assertTrue(!proxies.isEmpty());
    }
}
