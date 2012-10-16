package org.lantern;

import static org.junit.Assert.*;

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
        LanternHub.resetSettings(true);
        final Settings settings = LanternHub.settings();
        settings.setProxies(new HashSet<String>());
        final XmppHandler handler = new DefaultXmppHandler();
        handler.connect(user, pass);
        return handler;
    }

}
