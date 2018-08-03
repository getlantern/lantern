package org.lantern.oauth;

import java.io.IOException;

import javax.security.auth.callback.CallbackHandler;
import javax.security.auth.login.CredentialException;

import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.SASLAuthentication;
import org.jivesoftware.smack.XMPPException;
import org.jivesoftware.smack.packet.Packet;
import org.jivesoftware.smack.sasl.SASLMechanism;
import org.jivesoftware.smack.util.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.api.client.auth.oauth2.TokenResponse;


public class LanternSaslGoogleOAuth2Mechanism extends SASLMechanism {

    private final Logger log = LoggerFactory.getLogger(getClass());

    private ConnectionConfiguration config;

    private static OauthUtils oauthUtils;

    public LanternSaslGoogleOAuth2Mechanism(SASLAuthentication sa) {
        super(sa);
    }

    @Override
    protected String getName() {
        return "X-OAUTH2";
    }

    @Override
    public void authenticate(String username, String pass, String host) 
        throws IOException, XMPPException {
        throw new XMPPException("Google doesn't support password authentication in OAuth2.");
    }

    @Override
    public void authenticate(String username, String host,
            ConnectionConfiguration conf) throws IOException, XMPPException {
        this.config = conf;
        authenticate(username, host, config.getCallbackHandler());
    }
    
    @Override
    public void authenticate(String username, String host, CallbackHandler cbh) 
        throws IOException, XMPPException {
        log.debug("Authenticating...");
        
        //Set the authenticationID as the username, since they must be the same
        //in this case.
        this.authenticationId = username;
        this.hostname = host;

        final TokenResponse refreshed;
        try {
            refreshed = oauthUtils.oauthTokens();
        } catch (CredentialException e) {
            log.debug("Credentials error", e);
            throw new XMPPException("Credentials error", e);
        }
        final String accessToken = refreshed.getAccessToken();

        final String raw = "\0" + this.authenticationId + "\0" + accessToken;
        final String authenticationText = Base64.encodeBytes(
                raw.getBytes("UTF-8"),
                Base64.DONT_BREAK_LINES);
        // Send the authentication to the server
        getSASLAuthentication().send(new Packet() {
            @Override
            public String toXML() {
                return "<auth mechanism=\"X-OAUTH2\""
                        + " auth:service=\"oauth2\""
                        + " xmlns:auth=\"http://www.google.com/talk/protocol/auth\""
                        + " xmlns=\"urn:ietf:params:xml:ns:xmpp-sasl\">"
                        + authenticationText
                        + "</auth>";
            }
        });
    }
    
    public static void setOauthUtils(final OauthUtils oauthUtils) {
        LanternSaslGoogleOAuth2Mechanism.oauthUtils = oauthUtils;
    }
}
