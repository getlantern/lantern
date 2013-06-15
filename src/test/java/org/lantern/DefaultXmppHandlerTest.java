package org.lantern;

import static org.junit.Assert.assertTrue;

import org.jivesoftware.smack.SASLAuthentication;
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
        TestingUtils.newHttClientFactory();
        SASLAuthentication.registerSASLMechanism("X-OAUTH2", 
                LanternSaslGoogleOAuth2Mechanism.class);
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
        this.closedBetaEvent = null;

        final Censored censored = new DefaultCensored();
        final CountryService countryService = new CountryService(censored);
        final Model model = new Model(countryService);//.getModel();
        final org.lantern.state.Settings settings = model.getSettings();
        
        settings.setMode(Mode.get);
        settings.setAccessToken(TestingUtils.getAccessToken());
        settings.setRefreshToken(TestingUtils.getRefreshToken());
        settings.setUseGoogleOAuth2(true);
        
        
        final XmppHandler handler = TestingUtils.newXmppHandler(censored, model);
        handler.start();
        // The handler could have already been created and connected, so 
        // make sure we disconnect.
        handler.disconnect();
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
        
        handler.stop();
    }
}
