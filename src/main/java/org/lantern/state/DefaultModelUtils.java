package org.lantern.state;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Properties;
import java.util.Set;

import org.apache.commons.io.IOUtils;
import org.apache.commons.lang.StringUtils;
import org.lantern.LanternClientConstants;
import org.lantern.LanternUtils;
import org.lantern.event.Events;
import org.lantern.oauth.LanternGoogleOAuth2Credentials;
import org.lantern.oauth.OauthUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets.Details;
import com.google.inject.Inject;

/**
 * Utility methods that rely on all classes already having been bound using
 * Guice.
 */
public class DefaultModelUtils implements ModelUtils {

    private final Logger LOG = LoggerFactory.getLogger(DefaultModelUtils.class);
    
    private final Model model;

    @Inject
    public DefaultModelUtils(final Model model) {
        this.model = model;
    }
    
    /**
     * This is used for when the user disconnects and reconnects for any reason.
     * We store the users we know to have been in the closed beta so we don't
     * need to wait for a response from the lantern XMPP bot if we already
     * know they're invited.
     * 
     * Note the user will typically only be connecting with one IP addres, but
     * this setup ensures that any architecture changes the may change that 
     * won't affect invite lookups.
     * 
     * @param email The email to check.
     * @return <code>true</code> if we already know the specified user to be in
     * the closed beta. This will return <code>false</code> if we just don't
     * know -- they could be in or the could not be, but we haven't verified
     * they are in.
     */
    @Override
    public boolean isInClosedBeta(final String email) {
        final Set<String> in = this.model.getSettings().getInClosedBeta();
        return in.contains(email);
    }

    @Override
    public void addToClosedBeta(final String to) {
        final Set<String> in = this.model.getSettings().getInClosedBeta();
        in.add(to);
        this.model.getSettings().setInClosedBeta(in);
    }

    @Override
    public boolean shouldProxy() {
        return this.model.getSettings().isSystemProxy();
    }

    @Override
    public boolean isConfigured() {
        if (!LanternClientConstants.DEFAULT_MODEL_FILE.isFile()) {
            LOG.debug("No settings file");
            // It's possible it's configured in some other way, so keep
            // checking
        }
        final String refresh = this.model.getSettings().getRefreshToken();
        final boolean oauth = this.model.getSettings().isUseGoogleOAuth2();
        final boolean hasRefresh = StringUtils.isNotBlank(refresh);
        
        LOG.debug("Has refresh: "+hasRefresh);
        LOG.debug("Has oauth: "+oauth);
        return oauth && hasRefresh;
    }
    
    @Override
    public void loadClientSecrets() {
        final Details secrets;
        try {
            secrets = OauthUtils.loadClientSecrets().getInstalled();
        } catch (final IOException e) {
            LOG.error("Could not load client secrets?", e);
            throw new Error("Could not load client secrets?", e);
        }
        final String clientId = secrets.getClientId();
        final String clientSecret = secrets.getClientSecret();
        
        // Note the e-mail is actually ignored when we login to 
        // Google Talk.
        this.model.getSettings().setClientID(clientId);
        this.model.getSettings().setClientSecret(clientSecret);
    }

    @Override
    public LanternGoogleOAuth2Credentials newGoogleOauthCreds(final String resource) {
        final Settings set = this.model.getSettings();
        if (LanternUtils.isDevMode()) {
            final File oauth = LanternClientConstants.TEST_PROPS;
            if (!oauth.isFile()) {
                final Properties props = new Properties();
                props.put("refresh_token", set.getRefreshToken());
                props.put("access_token", set.getAccessToken());
                OutputStream os = null;
                try {
                    os = new FileOutputStream(oauth);
                    props.store(os, "Automatically stored test oauth tokens");
                } catch (final IOException e) {
                } finally {
                    IOUtils.closeQuietly(os);
                }
            } else {
                LOG.info("Not overwriting existing oauth file.");
            }
        }
        return new LanternGoogleOAuth2Credentials("anon@getlantern.org",
            set.getClientID(), set.getClientSecret(), 
            set.getAccessToken(), set.getRefreshToken(), 
            resource);
    }

    @Override
    public boolean isOauthConfigured() {
        final Settings set = this.model.getSettings();
        return StringUtils.isNotBlank(set.getRefreshToken()) &&
                StringUtils.isNotBlank(set.getAccessToken());
    }

    @Override
    public void syncConnectingStatus(final String msg) {
        this.model.getConnectivity().setConnectingStatus(msg);
        Events.syncConnectingStatus(msg);
    }
}
