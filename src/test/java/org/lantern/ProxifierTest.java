package org.lantern;

import org.apache.commons.lang.SystemUtils;
import org.junit.Test;
import org.lantern.oauth.LanternGoogleOAuth2Credentials;
import org.lantern.state.Model;
import org.lantern.state.ModelUtils;


public class ProxifierTest {

    @Test
    public void testOsxProxy() throws Exception {
        if (!SystemUtils.IS_OS_MAC_OSX) {
            return;
        }
        //Proxifier.proxyOsxViaScript();
        
        ModelUtils stub = newModelUtils();
        // Just make sure we don't get an exception
        final Censored censored = new DefaultCensored();
        final CountryService countryService = new CountryService(censored);
        new Proxifier(null, stub, new Model(countryService));
    }

    private ModelUtils newModelUtils() {
        return new ModelUtils() {
            
            @Override
            public boolean shouldProxy() {
                return true;
            }
            
            @Override
            public LanternGoogleOAuth2Credentials newGoogleOauthCreds(String resource) {
                return null;
            }
            
            @Override
            public void loadClientSecrets() {
            }
            
            @Override
            public boolean isInClosedBeta(String email) {
                return false;
            }
            
            @Override
            public boolean isConfigured() {
                return false;
            }
            
            @Override
            public void addToClosedBeta(String to) {}

            @Override
            public void syncConnectingStatus(String msg) {
                // TODO Auto-generated method stub

            }
        };
    }
}
