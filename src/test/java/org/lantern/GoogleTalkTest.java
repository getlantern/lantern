package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.util.HashSet;

import javax.security.auth.login.CredentialException;

import org.junit.Test;

public class GoogleTalkTest {
    
    @Test
    public void testGoogleTalk() throws Exception {
        TestUtils.getModel().getSettings().setUseAnonymousPeers(false);
        TestUtils.getModel().getSettings().setUseTrustedPeers(false);
        //final String email = TestUtils.loadTestEmail();
        final XmppHandler handler = createHandler();
        assertTrue("Not logged in to gtalk", handler.isLoggedIn());
    }
    
    private XmppHandler createHandler() 
        throws CredentialException, IOException, NotInClosedBetaException {
        TestUtils.getModel().getSettings().setProxies(new HashSet<String>());
        final XmppHandler xmpp = TestUtils.getXmppHandler();
        
        xmpp.connect();
        return xmpp;
    }

}
