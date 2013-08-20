package org.lantern.oauth;

import java.io.IOException;
import javax.security.auth.callback.Callback;
import javax.security.auth.callback.TextInputCallback;
import javax.security.auth.callback.CallbackHandler;
import javax.security.auth.callback.UnsupportedCallbackException;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.SASLAuthentication;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.littleshoot.commom.xmpp.XmppCredentials;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


public class LanternGoogleOAuth2Credentials implements XmppCredentials, CallbackHandler {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final String username;
    private final String resource;
    private final String clientID;
    private final String clientSecret;
    private final String accessToken;
    private final String refreshToken;

    public LanternGoogleOAuth2Credentials(final String username,
                                   final String clientID,
                                   final String clientSecret,
                                   final String accessToken,
                                   final String refreshToken) {
        this(username, clientID, clientSecret, accessToken,
             refreshToken, "SHOOT-");
    }

    public LanternGoogleOAuth2Credentials(final String username,
                                   final String clientID,
                                   final String clientSecret,
                                   final String accessToken,
                                   final String refreshToken,
                                   final String resource) {
        if (StringUtils.isNotBlank(username) && !username.contains("@")) {
            this.username = username + "@gmail.com";
        } else {
            this.username = username;
        }
        this.clientID = clientID;
        this.clientSecret = clientSecret;
        this.accessToken = accessToken;
        this.refreshToken = refreshToken;
        this.resource = resource;
    }

    @Override
    public String getUsername() {
        return username;
    }

    @Override
    public String getKey() {
        return username + refreshToken;
    }

    @Override
    public XMPPConnection createConnection(
        final ConnectionConfiguration config) {
        config.setCallbackHandler(this);
        final XMPPConnection conn = new XMPPConnection(config);
        
        // This just adds oauth2 to the mechanisms we support.
        SASLAuthentication.supportSASLMechanism("X-OAUTH2");
        return conn;
    }

    @Override
    public void login(final XMPPConnection conn) throws XMPPException {
        conn.login(username, null, resource);
    }

    @Override
    public void handle(final Callback[] callbacks) throws IOException,
        UnsupportedCallbackException {
        for (final Callback cb : callbacks) {
            if (cb instanceof TextInputCallback) {
                final TextInputCallback ticb = (TextInputCallback)cb;
                final String prompt = ticb.getPrompt();
                log.info("Got prompt: {}", prompt);
                if (prompt == "clientID") {
                    ticb.setText(clientID);
                } else if (prompt == "clientSecret") {
                    ticb.setText(clientSecret);
                } else if (prompt == "accessToken") {
                    ticb.setText(accessToken);
                } else if (prompt == "refreshToken") {
                    ticb.setText(refreshToken);
                } else {
                    throw new UnsupportedCallbackException(ticb, "Unrecognized prompt: " + ticb.getPrompt());
                }
            } else {
                throw new UnsupportedCallbackException(cb, "Unsupported callback type: "+cb+"\nthis: "+this);
            }
        }
    }
    

    @Override
    public String toString() {
        return "GoogleOAuth2Credentials [username=" + username + ", resource="
                + resource + ", clientID=" + clientID + ", clientSecret="
                + clientSecret + ", accessToken=" + accessToken
                + ", refreshToken=" + refreshToken + "]";
    }
}

