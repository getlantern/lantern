package org.lantern.oauth;

import org.apache.commons.lang.StringUtils;
import org.jivesoftware.smack.ConnectionConfiguration;
import org.jivesoftware.smack.SASLAuthentication;
import org.jivesoftware.smack.XMPPConnection;
import org.jivesoftware.smack.XMPPException;
import org.littleshoot.commom.xmpp.XmppCredentials;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class LanternGoogleOAuth2Credentials implements XmppCredentials {

    private final Logger log = LoggerFactory.getLogger(getClass());
    
    private final String username;
    private final String refreshToken;
    private final String resource;

    public LanternGoogleOAuth2Credentials(final String username,
            final String refreshToken,
            final String resource) {
        if (StringUtils.isNotBlank(username) && !username.contains("@")) {
            this.username = username + "@gmail.com";
        } else {
            this.username = username;
        }
        this.refreshToken = refreshToken;
        this.resource = resource;
    }
    
    @Override
    public String getUsername() {
        log.warn("OAUTH2 username");
        return username;
    }

    @Override
    public String getKey() {
        log.warn("OAUTH2 KEY");
        return username + refreshToken;
    }

    @Override
    public XMPPConnection createConnection(
        final ConnectionConfiguration config) {
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
    public String toString() {
        return "LanternGoogleOAuth2Credentials [username=" + username + ", resource="
                + resource 
                + ", refreshToken=" + refreshToken + "]";
    }
}

