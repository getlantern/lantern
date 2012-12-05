package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.util.HashSet;

import javax.security.auth.login.CredentialException;

import org.junit.Test;

public class GoogleTalkTest {
    
    @Test
    public void testGoogleTalk() throws Exception {
        LanternHub.settings().setUseAnonymousPeers(false);
        LanternHub.settings().setUseTrustedPeers(false);
        final String email = TestUtils.loadTestEmail();
        final XmppHandler handler = 
            createHandler(email, TestUtils.loadTestPassword());
        assertTrue("Not logged in to gtalk", handler.isLoggedIn());
    }
    
    private XmppHandler createHandler(final String user, final String pass) 
        throws CredentialException, IOException, NotInClosedBetaException {
        TestUtils.getModel().getSettings().setProxies(new HashSet<String>());
        final XmppHandler xmpp = TestUtils.getXmppHandler();
        
        xmpp.connect(user, pass);
        return xmpp;
    }

}
