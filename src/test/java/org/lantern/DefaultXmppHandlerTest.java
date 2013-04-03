package org.lantern;

import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.lantern.event.ClosedBetaEvent;
import org.lantern.event.Events;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.eventbus.Subscribe;

/**
 * Test for the XMPP handler.
 */
public class DefaultXmppHandlerTest {

    private static Logger LOG = 
        LoggerFactory.getLogger(DefaultXmppHandlerTest.class);
    
    private ClosedBetaEvent closedBetaEvent;
    
    public DefaultXmppHandlerTest() {
        Events.register(this);
    }
    
    @Subscribe
    public void onClosedBetaEvent(ClosedBetaEvent event) {
        this.closedBetaEvent = event;
    }
    
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
        //settings.setProxies(new HashSet<String>());
        
        settings.setMode(Mode.get);
        this.closedBetaEvent = null;
        
        final XmppHandler handler = TestUtils.getXmppHandler();
        handler.connect();
        
        assertTrue(handler.isLoggedIn());
        
        LOG.debug("Checking for proxies in settings: {}", settings);
        int count = 0;
        while (closedBetaEvent == null && count < 200) {
            Thread.sleep(100);
            count++;
        }
        
        assertTrue("Should have received event from the controller", 
            this.closedBetaEvent != null);
        //TestUtils.close();
    }
}
