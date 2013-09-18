package org.lantern;

import static org.junit.Assert.assertTrue;

import org.jivesoftware.smack.SASLAuthentication;
import org.junit.Test;
import org.lantern.oauth.LanternSaslGoogleOAuth2Mechanism;
import org.lantern.state.Mode;
import org.lantern.state.Model;
import org.lantern.util.HttpClientFactory;

public class GoogleTalkTest {
    
    @Test
    public void testGoogleTalk() throws Exception {
        
        SASLAuthentication.registerSASLMechanism("X-OAUTH2",
                LanternSaslGoogleOAuth2Mechanism.class);
        final HttpClientFactory httpClientFactory = TestingUtils.newHttClientFactory();
        LanternSaslGoogleOAuth2Mechanism.setHttpClientFactory(httpClientFactory);
        
        Launcher.configureCipherSuites();
        final Censored censored = new DefaultCensored();
        final CountryService countryService = new CountryService(censored);
        final Model model = new Model(countryService);
        final org.lantern.state.Settings settings = model.getSettings();
        
        settings.setMode(Mode.get);
        settings.setAccessToken(TestingUtils.accessToken());
        settings.setRefreshToken(TestingUtils.getRefreshToken());
        settings.setUseGoogleOAuth2(true);
        settings.setMode(Mode.give);
        settings.setUseAnonymousPeers(false);
        settings.setUseTrustedPeers(false);
        
        
        final XmppHandler handler = TestingUtils.newXmppHandler(censored, model);
        handler.start();
        // The handler could have already been created and connected, so 
        // make sure we disconnect.
        handler.disconnect();
        handler.connect();
        
        assertTrue("Not logged in to gtalk", handler.isLoggedIn());
    }
    

}
