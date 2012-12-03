package org.lantern;

import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.util.HashSet;

import javax.security.auth.login.CredentialException;

import org.junit.BeforeClass;
import org.junit.Test;

import com.google.inject.Guice;
import com.google.inject.Injector;

public class GoogleTalkTest {

    private static DefaultXmppHandler xmpp;
    
    @BeforeClass
    public static void setup() throws Exception {
        final Injector injector = Guice.createInjector(new LanternModule());
        
        // Order annoyingly matters -- have to create xmpp handler first.
        xmpp = injector.getInstance(DefaultXmppHandler.class);
        xmpp.start();
    }
    
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
        //final XmppHandler handler = new DefaultXmppHandler();
        xmpp.connect(user, pass);
        return xmpp;
    }

}
